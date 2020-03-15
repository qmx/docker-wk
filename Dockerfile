ARG SSH_HOST_KEYS_HASH=sha256:9a6630c2fbed11a3f806c5a5c1fe1550b628311d8701680fd740cae94b377e6c

FROM qmxme/base-tools:0.0.2 as base_tools_builder

# golang tools
FROM qmxme/golang-tools:1.0.1 as golang_builder

# rust-analyzer
FROM qmxme/rust-analyzer:1.2.0 as ra_builder

# rust tools
FROM qmxme/rust-tools:1.2.1 as rust_tools_builder

# rust web tools
FROM qmxme/rust-web-tools:1.0.0 as rust_web_builder

# rust extra tools
FROM qmxme/rust-extra-tools:0.1.0 as rust_extra_builder

# some individually compiled tools
FROM qmxme/curl as tool_cargo-docserver
ARG TARGETARCH
ARG TARGETVARIANT
RUN curl -sL -o /usr/local/bin/cargo-docserver "$(curl -sL https://api.github.com/repos/qmx/cargo-docserver/releases/tags/v0.3.0 | jq -r '.assets[].browser_download_url' | grep $TARGETARCH$TARGETVARIANT)"
RUN chmod +x /usr/local/bin/cargo-docserver

FROM qmxme/curl as tool_cpubars
ARG TARGETARCH
ARG TARGETVARIANT
RUN curl -sL -o /usr/local/bin/cpubars "$(curl -sL https://api.github.com/repos/qmx/cpubars/releases/tags/v0.4.3 | jq -r '.assets[].browser_download_url' | grep $TARGETARCH$TARGETVARIANT)"
RUN chmod +x /usr/local/bin/cpubars

FROM qmxme/curl as tool_wk
ARG TARGETARCH
ARG TARGETVARIANT
RUN curl -sL -o /usr/local/bin/wk "$(curl -sL https://api.github.com/repos/qmx/wk-cli/releases/tags/v0.4.2 | jq -r '.assets[].browser_download_url' | grep $TARGETARCH$TARGETVARIANT)"
RUN chmod +x /usr/local/bin/wk

# install terraform
FROM qmxme/curl as terraform_builder
ARG TARGETARCH
RUN curl -L -o /tmp/terraform.zip https://releases.hashicorp.com/terraform/0.12.18/terraform_0.12.18_linux_$TARGETARCH.zip
RUN cd /usr/local/bin && unzip /tmp/terraform.zip && chmod 755 /usr/local/bin/terraform

# install kubectl
FROM qmxme/curl as kubectl_builder
ARG TARGETARCH
RUN curl -L -o /usr/local/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/$TARGETARCH/kubectl
RUN chmod 755 /usr/local/bin/kubectl

# install helm
FROM qmxme/curl as helm_builder
ARG TARGETARCH
RUN curl -L -o /tmp/helm.tar.gz https://get.helm.sh/helm-v3.0.0-linux-$TARGETARCH.tar.gz
WORKDIR /tmp
RUN tar -zxvf helm.tar.gz
RUN cp linux-$TARGETARCH/helm /usr/local/bin

# install coursier
FROM qmxme/curl as coursier_builder
RUN curl -L -o /usr/local/bin/coursier https://github.com/coursier/coursier/releases/download/v2.0.0-RC5-2/coursier
RUN chmod 755 /usr/local/bin/coursier

# SSH host keys
FROM qmxme/openssh@$SSH_HOST_KEYS_HASH as ssh_host_keys

# base distro
FROM qmxme/base:0.1.3

# base tools
COPY --from=base_tools_builder /usr/local/bin/* /usr/local/bin/

# golang tools
COPY --from=golang_builder /usr/local/bin/* /usr/local/bin/

# rust essential crates
COPY --from=ra_builder /opt/rust-tools/bin/* /usr/local/bin/
COPY --from=rust_tools_builder /usr/local/bin/* /usr/local/bin/
COPY --from=rust_web_builder /usr/local/bin/* /usr/local/bin/
COPY --from=rust_extra_builder /usr/local/bin/* /usr/local/bin/

# some individually compiled tools
COPY --from=tool_cpubars /usr/local/bin/* /usr/local/bin/
COPY --from=tool_cargo-docserver /usr/local/bin/* /usr/local/bin/
COPY --from=tool_wk /usr/local/bin/* /usr/local/bin/

# terraform
COPY --from=terraform_builder /usr/local/bin/terraform /usr/local/bin/

# kubectl
COPY --from=kubectl_builder /usr/local/bin/kubectl /usr/local/bin/

# helm
COPY --from=helm_builder /usr/local/bin/helm /usr/local/bin/

# coursier
COPY --from=coursier_builder /usr/local/bin/coursier /usr/local/bin/

# user setup
ARG user=qmx
ARG uid=1000
ARG github_user=qmx
RUN useradd -m $user -u $uid -G users,sudo,docker -s /bin/zsh
USER $user
RUN mkdir ~/.ssh && curl -fsL https://github.com/$github_user.keys > ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys

# some empty folders, with proper permissions
RUN mkdir -p ~/bin ~/.cargo/bin ~/.config ~/tmp ~/.gnupg ~/.local ~/.vim && chmod 700 ~/.gnupg

# install metals-vim
RUN coursier bootstrap  --java-opt -Xss4m --java-opt -Xms100m --java-opt -Dmetals.client=coc.nvim org.scalameta:metals_2.12:0.7.6 -r bintray:scalacenter/releases -o ~/bin/metals-vim -f

# dotfile setup
RUN git clone -b 1.5.2 --recursive https://github.com/qmx/dotfiles.git ~/.dotfiles
RUN cd ~/.dotfiles && stow -v .

# install rust
RUN curl -sSf https://sh.rustup.rs | zsh -s -- -y --default-toolchain 1.42.0
RUN . /home/$user/.cargo/env && rustup component add rustfmt rust-src rls
RUN vim -c 'CocInstall -sync |q'

# make sure we start sshd at the end - always keep this at the bottom
USER root
EXPOSE 3222
ADD entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-D"]
