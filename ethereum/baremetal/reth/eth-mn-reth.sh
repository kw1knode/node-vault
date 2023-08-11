#!/bin/bash

######################################################################################
#####################             PREREQUISITES                #######################
###################################################################################### 

sudo apt update -y && sudo apt upgrade -y && sudo apt auto-remove -y
sudo apt-get install -y build-essential ufw git libclang-dev pkg-config
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp #ssh
sudo ufw allow 30303 #erigon peers
sudo ufw allow 9000 #lh peers
sudo ufw --force enable
sudo ufw status verbose

######################################################################################
#####################               INSTALL RUST               #######################
###################################################################################### 

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
echo "export PATH=$PATH:$HOME/.cargo/bin/env:$PATH" >> $HOME/.profile
source $HOME/.profile

######################################################################################
#####################              PREPARE RUST & LH                ##################
###################################################################################### 

udo useradd --no-create-home --shell /bin/false reth
sudo useradd --no-create-home --shell /bin/false lighthousebeacon
sudo mkdir -p /var/lib/reth
sudo mkdir -p /var/lib/lighthouse
sudo chown -R reth:reth /var/lib/reth
sudo chown -R lighthousebeacon:lighthousebeacon /var/lib/lighthouse
openssl rand -hex 32 | sudo tee -a /var/lib/reth/jwt.hex > /dev/null

######################################################################################
#####################                 BUILD RETH                    ##################
###################################################################################### 

git clone https://github.com/paradigmxyz/reth
cd reth
RUSTFLAGS="-C target-cpu=native" cargo build --profile maxperf
cp $HOME/reth/target/maxperf/reth /usr/local/bin
rm -r reth


sudo echo "[Unit]
Description=Reth Mainnet Service
After=network.target
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
Type=simple
Restart=on-failure
RestartSec=5
TimeoutSec=900
User=reth
Group=reth
Nice=0
LimitNOFILE=200000
WorkingDirectory=/var/lib/reth/
ExecStart=/usr/local/bin/reth \
        --datadir=/var/lib/reth \
        --chain mainnet \
        --authrpc.jwtsecret=/var/lib/reth/jwt.hex \
        --authrpc.port=8552 \
        --http \
        --http.addr=0.0.0.0 \
        --http.port=8546 \
        --http.corsdomain=* \
        --http.api=eth,debug,net,trace,web3,erigon \
        --ws \
        --metrics=0.0.0.0:6060
        
KillSignal=SIGHUP

[Install]
WantedBy=multi-user.target" | sudo tee -a /etc/systemd/system/reth.service > /dev/null

