#cloud-config
package_update: true
package_upgrade: true

packages:
  - openjdk-11-jdk
  - unzip
  - curl
  - wget
  - sysstat
  - htop
  - iotop
  - jq
  - python3
  - python3-pip

write_files:
  - path: /etc/environment
    content: |
      JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
      TALEND_HOME=/opt/talend/remote-engine
      TALEND_WORKSPACE=/data/talend/work
    append: true
  - path: /etc/systemd/system/talend-remote-engine.service
    content: |
      [Unit]
      Description=Talend Remote Engine
      After=network.target

      [Service]
      Type=forking
      User=${admin_username}
      Environment="JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64"
      Environment="TALEND_HOME=/opt/talend/remote-engine"
      WorkingDirectory=/opt/talend/remote-engine
      ExecStart=/opt/talend/remote-engine/start.sh
      ExecStop=/opt/talend/remote-engine/stop.sh
      Restart=on-failure
      RestartSec=10

      [Install]
      WantedBy=multi-user.target

runcmd:
  - mkdir -p /opt/talend /data/talend/{work,logs,temp}
  - |
    # Initialize and mount data disk
    if [ -b /dev/sdc ]; then
      mkfs.ext4 -F /dev/sdc
      mount /dev/sdc /data
      echo '/dev/sdc /data ext4 defaults,nofail 0 0' >> /etc/fstab
    fi
  - chown -R ${admin_username}:${admin_username} /data/talend
  - chown -R ${admin_username}:${admin_username} /opt/talend
  - systemctl enable sysstat
  - systemctl start sysstat
  - echo "Cloud-init setup completed" > /var/log/cloud-init-complete.log

final_message: "Talend Remote Engine VM setup completed. Time: $UPTIME"
