FROM alpine:latest

ARG GUIX_VERSION=0.16.0
ENV GUIX_VERSION=$GUIX_VERSION

# Install dependencies
RUN apk add gnupg shadow

# Download tarball and signature
RUN wget --output-document=/tmp/guix-binary-$GUIX_VERSION.x86_64-linux.tar.xz \
	"https://alpha.gnu.org/gnu/guix/guix-binary-$GUIX_VERSION.x86_64-linux.tar.xz"
RUN wget --output-document=/tmp/guix-binary-$GUIX_VERSION.x86_64-linux.tar.xz.sig \
	"https://alpha.gnu.org/gnu/guix/guix-binary-$GUIX_VERSION.x86_64-linux.tar.xz.sig"

# Verify download
RUN gpg --recv-keys 3CE464558A84FDC69DB40CFB090B11993D9AEBB5
RUN gpg --verify /tmp/guix-binary-$GUIX_VERSION.x86_64-linux.tar.xz.sig

# Extract and install directories
RUN tar xJ -C / -f /tmp/guix-binary-$GUIX_VERSION.x86_64-linux.tar.xz

# Install profiles
RUN mkdir -p ~root/.config/guix
RUN ln -sf /var/guix/profiles/per-user/root/current-guix ~root/.config/guix/current
RUN GUIX_PROFILE="`echo ~root`/.config/guix/current" ; \
	source $GUIX_PROFILE/etc/profile

# Install command
RUN mkdir -p /usr/local/bin
RUN ln -s /var/guix/profiles/per-user/root/current-guix/bin/guix /usr/local/bin/guix

# Create build users
RUN groupadd --system guixbuild
RUN for i in `seq -w 1 10`; do \
	useradd \
		-g guixbuild \
		-G guixbuild \
		-d /var/empty \
		-s `which nologin` \
		-c "Guix build user $i" \
		--system \
        guixbuilder$i; \
	done

# Enable substitutes
RUN guix archive --authorize < ~root/.config/guix/current/share/guix/ci.guix.info.pub

# Create convenience `guix-daemon` command
RUN echo -e '#!/bin/sh\n\
~root/.config/guix/current/bin/guix-daemon --build-users-group=guixbuild &\n'\
>> /usr/local/bin/guix-daemon && chmod +x /usr/local/bin/guix-daemon
