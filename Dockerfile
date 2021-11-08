FROM quyo/wolframengine:12.3.1-20.04

MAINTAINER Markus John <johm@quyo.de>

USER root

ENV DEBIAN_FRONTEND=noninteractive

#
# Install ubuntu packages
#
RUN apt-get update \
 && apt-get install -y \
      curl \
      tzdata \
 && rm -rf /var/lib/apt/lists/*

RUN ln -fs /usr/share/zoneinfo/Europe/Berlin /etc/localtime \
 && dpkg-reconfigure --frontend noninteractive tzdata

#
# Install Julia
#
ARG JULIA=1.6.3
RUN cd /tmp \
 && curl -f -sS -L -o julia-${JULIA}-linux-x86_64.tar.gz https://julialang-s3.julialang.org/bin/linux/x64/${JULIA%.*}/julia-${JULIA}-linux-x86_64.tar.gz \
 && tar xf julia-${JULIA}-linux-x86_64.tar.gz -C /opt \
 && rm -f julia-${JULIA}-linux-x86_64.tar.gz \
 && mv /opt/julia-* /opt/julia \
 && ln -s /opt/julia/bin/julia /usr/local/bin

#
# Install more ubuntu packages
#
RUN apt-get update \
 && apt-get install -y \
      libxcursor1 \
      libxft2 \
      libxrandr2 \
 && rm -rf /var/lib/apt/lists/* \
 && cd /tmp \
 && curl -f -sS -L -o maxima-common_5.44.0-1_all.deb https://fs.quyo.net/maxima/maxima-common_5.44.0-1_all.deb \
 && curl -f -sS -L -o maxima-sbcl_5.44.0-1_amd64.deb https://fs.quyo.net/maxima/maxima-sbcl_5.44.0-1_amd64.deb \
 && dpkg -i maxima-common_5.44.0-1_all.deb \
 && dpkg -i maxima-sbcl_5.44.0-1_amd64.deb \
 && rm -f *.deb

#
# Install Klio.jl
#
RUN adduser --quiet --shell /bin/bash --gecos "Klio,101,," --disabled-password klio

COPY ./initialize.jl     /home/klio/Klio.jl/
COPY ./Project.toml      /home/klio/Klio.jl/
COPY ./src/Klio-empty.jl /home/klio/Klio.jl/src/Klio.jl
RUN chown -R klio:klio /home/klio/

USER klio
RUN julia --project=/home/klio/Klio.jl /home/klio/Klio.jl/initialize.jl

USER root
COPY ./ /home/klio/Klio.jl/
RUN chown -R klio:klio /home/klio/Klio.jl/

USER klio
RUN julia --project=/home/klio/Klio.jl /home/klio/Klio.jl/initialize.jl


EXPOSE 8000

HEALTHCHECK  --interval=1m --timeout=30s \
  CMD /home/klio/Klio.jl/sh/ping-klio || exit 1

CMD /home/klio/Klio.jl/sh/start-klio
