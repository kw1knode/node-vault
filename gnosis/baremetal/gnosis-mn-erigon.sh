#!/bin/bash

ERI_VER=2.48.1

######################################################################################
#####################             PREREQUISITES                #######################
###################################################################################### 

sudo apt update -y && sudo apt upgrade -y && sudo apt auto-remove -y
sudo apt install -y git cmake pkg-config llvm-dev libclang-dev clang protobuf-compiler ufw build-essential
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp #ssh
sudo ufw allow 30303 #erigon peers
sudo ufw allow 9000 #lh peers
sudo ufw --force enable
sudo ufw status verbose

######################################################################################
#####################             INSTALL GO & RUST            #######################
###################################################################################### 

ver="1.20.5"
cd $HOME
wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz"
rm "go$ver.linux-amd64.tar.gz"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin:$HOME/.cargo/bin/env:$PATH" >> $HOME/.profile
source $HOME/.profile

######################################################################################
#####################            PREPARE ERIGON & LH                ##################
###################################################################################### 

sudo useradd --no-create-home --shell /bin/false erigon
sudo useradd --no-create-home --shell /bin/false lighthousebeacon
sudo mkdir -p /var/lib/erigon
sudo mkdir -p /var/lib/lighthouse
sudo chown -R erigon:erigon /var/lib/erigon
sudo chown -R lighthousebeacon:lighthousebeacon /var/lib/lighthouse
openssl rand -hex 32 | sudo tee -a /var/lib/erigon/jwt.hex > /dev/null

######################################################################################
#####################               BUILD ERIGON                    ##################
###################################################################################### 

cd ~
git clone --recurse-submodules https://github.com/ledgerwatch/erigon.git
cd erigon
git checkout $ERI_VER
make
cp $HOME/erigon/build/bin/erigon /usr/local/bin
rm -r erigon


sudo echo "[Unit]
Description=Erigon Gnosis Mainnet Service
After=network.target
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
Type=simple
Restart=on-failure
RestartSec=5
TimeoutSec=900
User=erigon
Group=erigon
Nice=0
LimitNOFILE=200000
WorkingDirectory=/var/lib/erigon
ExecStart=/usr/local/bin/erigon \\
        --datadir=/var/lib/erigon \\
        --ethash.dagdir=/var/lib/erigon/ethash \\
        --chain gnosis \\
        --authrpc.jwtsecret=/var/lib/erigon/jwt.hex \\
        --authrpc.port=8552 \\
        --http \\
        --http.addr=0.0.0.0 \\
        --http.port=8546 \\
        --http.compression \\
        --http.vhosts=* \\
        --http.corsdomain=* \\
        --http.api=eth,debug,net,trace,web3,erigon \\
        --private.api.addr=0.0.0.0:9091 \\
        --ws --ws.compression \\
        --metrics --metrics.addr=0.0.0.0 --metrics.port=6060 \\
        --torrent.download.rate 1024mb \\
        --rpc.returndata.limit=1000000
KillSignal=SIGHUP

[Install]
WantedBy=multi-user.target" | sudo tee -a /etc/systemd/system/erigon.service > /dev/null

######################################################################################
#####################             BUILD LIGHTHOUSE                  ##################
###################################################################################### 

cd ~
git clone https://github.com/sigp/lighthouse.git
cd lighthouse
git checkout stable
FEATURES=gnosis make
cp $HOME/lighthouse/target/release /usr/local/bin
rm -r lighthouse

sudo echo "[Unit]
Description=LightHouse Beacon Gnosis Service
After=network.target
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
Type=simple
Restart=on-failure
RestartSec=5
TimeoutSec=900
User=lighthousebeacon
Group=lighthousebeacon
Nice=0
LimitNOFILE=200000
ExecStart=/usr/local/bin/lighthouse bn \\
        --datadir=/var/lib/lighthouse \\
        --network=gnosis \\
        --http \\
        --metrics \\
        --metrics-port=5064 \\
        --port=9001 \\
        --execution-endpoint=http://127.0.0.1:8552 \\
        --execution-jwt=/var/lib/erigon/jwt.hex

KillSignal=SIGHUP

[Install]
WantedBy=multi-user.target" | sudo tee -a /etc/systemd/system/lighthousebeacon.service > /dev/null





