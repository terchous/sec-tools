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
		"build-essential"
		"libssl-dev"
		"zlib1g-dev"
		"libbz2-dev"
		"libreadline-dev"
		"libsqlite3-dev"
		"curl"
		"libncursesw5-dev"
		"xz-utils"
		"tk-dev"
		"libxml2-dev"
		"libxmlsec1-dev"
		"libffi-dev"
		"liblzma-dev"
        )

declare -A go_pkg

go_pkg[subfinder]="go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
go_pkg[httpx]="go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest"
go_pkg[nuclei]="go install -v github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest"
go_pkg[notify]="go install -v github.com/projectdiscovery/notify/cmd/notify@latest"
go_pkg[anew]="go install -v github.com/tomnomnom/anew@latest"
go_pkg[httprobe]="go install -v github.com/tomnomnom/httprobe@latest"
go_pkg[gobuster]="go install -v github.com/OJ/gobuster/v3@latest"
go_pkg[meg]="go install -v github.com/tomnomnom/meg@latest"
go_pkg[naabu]="go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest"
go_pkg[jaeles]="go install -v github.com/jaeles-project/jaeles@latest"
go_pkg[amass]="go install -v github.com/owasp-amass/amass/v4/...@master"
go_pkg[gospider]="go install -v github.com/jaeles-project/gospider@latest"
go_pkg[chaos]="go install -v github.com/projectdiscovery/chaos-client/cmd/chaos@latest"
go_pkg[gf]="go install -v github.com/tomnomnom/gf@latest"
go_pkg[assetfinder]="go install -v github.com/tomnomnom/assetfinder@latest"
go_pkg[airixss]="go install -v github.com/ferreiraklet/airixss@latest"
go_pkg[cariddi]="go install -v github.com/edoardottt/cariddi/cmd/cariddi@latest"
go_pkg[dalfox]="go install -v github.com/hahwul/dalfox/v2@latest"
go_pkg[filter-resolved]="go install -v github.com/tomnomnom/hacks/filter-resolved@latest"
go_pkg[ffuf]="go install -v github.com/ffuf/ffuf/v2@latest"
go_pkg[gau]="go install -v github.com/lc/gau/v2/cmd/gau@latest"
go_pkg[hakrawler]="go install -v github.com/hakluke/hakrawler@latest"
go_pkg[haklistgen]="go install -v github.com/hakluke/haklistgen@latest"
go_pkg[waybackurls]="go install -v github.com/tomnomnom/waybackurls@latest"
go_pkg[goop]="go install -v github.com/deletescape/goop@latest"
go_pkg[katana]="go install -v github.com/projectdiscovery/katana/cmd/katana@latest"

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

function install_pipx(){
	python -m pip install pipx --user
}

function install_paramspider(){
	pipx install https://github.com/devanshbatham/ParamSpider.git
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
	go_install "naabu" "{$go_pkg[naabu]}"
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


function install_gau(){
        FILE="~/go/bin/gau"
        if [ -f "$FILE" ];
        then
                echo "GetAllUrls alerady installed..."
        else
                echo "Installing GetAllUrls..."
                go install github.com/lc/gau/v2/cmd/gau@latest
                echo "Installed GetAllUrls..."
        fi
}


function install_amass(){
        FILE="~/go/bin/amass"
        if [ -f "$FILE" ];
        then
                echo "amass already installed..."
        else
                echo "Installing GetAllUrls..."
		go install -v github.com/owasp-amass/amass/v4/...@master
                echo "Installed amass"
        fi
}


function go_install(){
	FILE="~/go/bin/$1"
	if [ -f "$FILE" ];
	then
		echo "$1 already installed..."
	else
		echo "Installing $1"
		$2
		echo "Installed $1"
	fi
}

function install_go_tools(){
	for package in "${!go_pkg[@]}"
	do
		echo "$package ${go_pkg[$package]}"
		go_install "$package" "${go_pkg[$package]}"
	done
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
   install_naabu
   install_go_tools
   install_git_lfs
   install_pipx
   install_paramspider
   download_seclists
   download_kj_ips
}

main
