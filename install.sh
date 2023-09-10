#!/bin/bash
# based on BBT https://github.com/nahamsec/bbht/blob/master/install.sh

declare -a arr=("httping"
                "nmap"
                "fping"
                "bat"
                "tldr"
                "tmux"
                "jq"
                "dirb"
		"nmap"
		"fping"
		"ripgrep"
                "nethogs"
                "iptraf"
                "htop"
                "tree"
        )

function package_update() {
    sudo apt-get update -yq
}

function package_upgrade() {
    sudo apt-get upgrade -yq
}

function package_install() {
    sudo apt-get install $1 -yq
}

# pyenv install
function install_pyenv(){
        if [ -d ~/.pyenv ];
        then
                echo "Pyenv is installed..."
                # TODO add pyenv to ~/.bashrc
                # export PYENV_ROOT="$HOME/.pyenv"
                # command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
                # eval "$(pyenv init -)"
        else
                echo "Installing pyenv..."
                curl https://pyenv.run | bash
        fi
}

function install_golang(){
	GO_VERSION="1.20.1"
	if [ -d "/usr/local/go/bin" ];
	then
		echo "Go $(go version) installed..."
	else
		wget https://go.dev/dl/go$GO_VERSION.linux-amd64.tar.gz
		tar -xzf go$GO_VERSION.linux-amd64.tar.gz
		sudo mv go /usr/local/
		rm -f go$GO_VERSION.linux-amd64.tar.gz
		echo "Installed Go $(go version)"
	fi
        #package_install golang-go
        #TODO add to .bashrc
        #export PATH=$PATH:/usr/local/go/bin:~/go/bin
}

function install_projectdiscovery_tools(){
        if [ -f "~/go/bin/subfinder" ];
        then
                echo "Subfinder installed"
        else
                echo "Installing Subfinder..."
                go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
                echo "Installed subfinder..."
        fi

        if [ -f "~/go/bin/httpx" ];
        then
                echo "httpx installed"
        else
                echo "Installing httpx..."
                go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
                echo "Installed subfinder..."
        fi

        if [ -f "~/go/bin/nuclei" ];
        then
                echo "nuclei installed"
        else
                echo "Installing nuclei..."
                go install -v github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest
                echo "Installed nuclei..."
        fi


        if [ -f "~/go/bin/notify" ];
        then
                echo "notify installed"
        else
                echo "Installing notify..."
                go install -v github.com/projectdiscovery/notify/cmd/notify@latest
                echo "Installed notify..."
        fi                                                                                                                                                                              
        if [ -f "~/go/bin/anew" ];
        then
                echo "anew installed"
        else
                echo "Installing anew..."
                go install -v github.com/tomnomnom/anew@latest
                echo "Installed anew..."
        fi

        if [ -f "~/go/bin/httprobe" ];
        then
                echo "httprobe installed"
        else
                echo "Installing httprobe..."
                go install github.com/tomnomnom/httprobe@latest
                echo "Installed httprobe..."
        fi

}

function install_gobuster(){
        FILE="~/go/bin/gobuster"
        if [ -f "$FILE" ];
        then
                echo "GoBuster alerady installed..."
        else
                echo "Installing gobuster..."
                go install github.com/OJ/gobuster/v3@latest
                echo "Installed gobuster..."
        fi
}

function install_meg(){
    FILE="~/go/bin/meg"
    if [ -f "$FILE" ];
    then
        echo "meg alerady installed..."
    else
        echo "Installing meg..."
        go install github.com/tomnomnom/meg@latest
        echo "Installed meg..."
    fi
    
}

function install_naabu(){
	package_install libpcap-dev
        if [ -f "~/go/bin/naabu" ];
        then
                echo "naabu installed"
        else
                echo "Installing naabu..."
		go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest
                echo "Installed naabu..."
        fi
}

function install_jaeles(){
        if [ -f "~/go/bin/jaeles" ];
        then
                echo "jaeles installed"
        else
                echo "Installing jaeles..."
		go install github.com/jaeles-project/jaeles@latest
                echo "Installed jaeles..."
        fi
}

function install_masscan(){
    FILE="/usr/local/bin/masscan"

    if [ -f "$FILE" ];
    then
        echo "MasScan already installed"
    else
        echo "Installing masScan..."
        sudo apt-get -yq install git make gcc
        git clone https://github.com/robertdavidgraham/masscan
        cd masscan
        make
        sudo make install
        cd ~
        echo "Installed masscan..."
    fi

}

function download_seclists(){
        if [ -d ~/wordlists/seclists ];
        then
                echo "SecLists downloaded already..."
        else
                mkdir ~/wordlists
                git clone https://github.com/danielmiessler/SecLists.git ~/wordlists/seclists
        fi
}

function download_kj_ips(){
        if [ -d ~/iplists/kaeferjaeger ];
        then
                echo "KJ already downloaded..."
        else
                mkdir -p ~/iplists/kaeferjaeger
                wget https://kaeferjaeger.gay/sni-ip-ranges/amazon/ipv4_merged_sni.txt -O ~/iplists/kaeferjaeger/amazon_ipv4_merged_sni.txt
                wget https://kaeferjaeger.gay/sni-ip-ranges/digitalocean/ipv4_merged_sni.txt -O ~/iplists/kaeferjaeger/digitalocean_ipv4_merged_sni.txt
                wget https://kaeferjaeger.gay/sni-ip-ranges/google/ipv4_merged_sni.txt -O ~/iplists/kaeferjaeger/google_ipv4_merged_sni.txt
                wget https://kaeferjaeger.gay/sni-ip-ranges/microsoft/ipv4_merged_sni.txt -O ~/iplists/kaeferjaeger/microsoft_ipv4_merged_sni.txt
                wget https://kaeferjaeger.gay/sni-ip-ranges/oracle/ipv4_merged_sni.txt -O ~/iplists/kaeferjaeger/oracle_ipv4_merged_sni.txt
        fi

}
# Grab the bbht

function install_git_lfs(){
	curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash
	package_install git-lfs
	git lfs install
}

function main(){
    package_update
    package_upgrade

    for package in "${arr[@]}"
    do
            echo "Installing $package"
            package_install $package
            echo "Installed $package"
    done
    install_golang
    install_pyenv
    install_projectdiscovery_tools
    install_gobuster
    install_meg
    install_masscan
    install_git_lfs
    install_naabu
    install_jaeles
    download_seclists
    download_kj_ips
}

main
