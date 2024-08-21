#!/bin/bash

# 버전 정보 출력
echo "OS-LAB DISK_INFO v. 1.0 (24.08.21)"

# 루트 파티션을 식별하기 위한 변수
root_disk=$(findmnt -n -o SOURCE /)

for disk in /dev/sd?; do
    # 디스크 이름 추출 (/dev/sda 등)
    name=$(basename $disk)
    
    # 디스크 용량 추출
    size=$(lsblk -d -o SIZE -n $disk)
    
    # 인터페이스 타입 추출
    tran=$(lsblk -d -o TRAN -n $disk)
    
    # 디스크 종류 결정 (ROTA: 0이면 SSD, 1이면 HDD)
    rota=$(lsblk -d -o ROTA -n $disk)
    if [ "$rota" -eq 0 ]; then
        if [ "$tran" = "nvme" ]; then
            disk_type="NVMe SSD"
        elif [ "$tran" = "usb" ]; then
            disk_type="USB Flash Drive"
        else
            disk_type="SSD"
        fi
    else
        if [ "$tran" = "usb" ]; then
            disk_type="External HDD"
        else
            disk_type="HDD"
        fi
    fi
    
    # 제조사 정보 추출 (udevadm 사용)
    model=$(udevadm info --query=all --name=$disk | grep ID_MODEL= | awk -F= '{print $2}' | xargs)
    
    # 파티션 정보 추출
    lsblk -ln -o NAME,FSTYPE,UUID,MOUNTPOINT $disk | while read part_name fstype uuid mountpoint; do
        # 절대 경로로 파티션 경로 가져오기
        part_path=$(lsblk -lp -o NAME | grep -w "/dev/$part_name")

        # 디스크 사용량 정보 추가
        usage_info=$(df -h "$part_path" 2>/dev/null | awk 'NR==2 {print "U: "$3" / F: "$4}')
        
        # 파티션 상태 결정
        if [ "$part_path" == "$root_disk" ]; then
            status="Mounted at $mountpoint"
        elif [ -z "$fstype" ]; then
            status="Unallocated"
        elif [ -z "$mountpoint" ]; then
            status="No Mount Point"
        else
            status="Mounted at $mountpoint"
        fi

        # 출력 형식
        if [ -n "$fstype" ] && [ -n "$uuid" ]; then
            echo "$part_path ($status) | $disk_type ($tran) | $size ($usage_info) | $model | $fstype | UUID: $uuid"
        else
            echo "$part_path ($status) | $disk_type ($tran) | $size ($usage_info) | $model | Unknown | UUID: None"
        fi
    done
done
