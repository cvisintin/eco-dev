FROM ubuntu
MAINTAINER William K Morris <wkmor1@gmail.com>

# Versions
ENV RSTUDIOVER 0.99.491
ENV SHINYVER   1.5.0.730
ENV JULIAVER   0.4.3
ENV BUGSVER    3.2.3-1

# Set env vars
ENV PATH        /opt/julia:/usr/lib/rstudio-server/bin:/zonation/zig4:$PATH
ENV R_LIBS_USER ~/.r-dir/R/library

# Create directories
RUN    mkdir -p \
         /opt/julia \
         /zonation \
         /var/log/supervisor \
         /var/run/sshd

# Install Ubuntu packages
RUN    apt-get update \
    && apt-get install -y --no-install-recommends \
         apt-transport-https \
         cmake \
         curl \
         default-jre \
         gdal-bin \
         gdebi-core \
         gfortran \
         git \
         libboost-filesystem-dev \
         libboost-program-options-dev \
         libboost-thread-dev \
         libgdal-dev \
         libproj-dev \
         libv8-dev \
         libzmq3-dev \
         octave \
         openssh-server \
         python3-dev \
         python3-pip \
         supervisor 

# Download Rstudio, Shiny, Julia, OpenBUGS and Zonation,
RUN    curl \
         -O https://download2.rstudio.org/rstudio-server-$RSTUDIOVER-amd64.deb \
         -O https://s3.amazonaws.com/rstudio-shiny-server-os-build/ubuntu-12.04/x86_64/shiny-server-$SHINYVER-amd64.deb \
         -O https://julialang.s3.amazonaws.com/bin/linux/x64/0.4/julia-$JULIAVER-linux-x86_64.tar.gz \
         -O http://pj.freefaculty.org/Ubuntu/15.04/amd64/openbugs/openbugs_${BUGSVER}_amd64.deb \
         -OL https://bintray.com/artifact/download/wkmor1/binaries/zonation.tar.gz 

# Install Jupyter
RUN    pip3 install jupyter ipyparallel

# Install Julia
RUN    tar xzf julia-$JULIAVER-linux-x86_64.tar.gz -C /opt/julia --strip 1 \
    && ln -s /opt/julia/bin/julia /usr/local/bin/julia

# Install R, RStudio, Shiny, Jags and OpenBUGS
RUN     echo "deb http://ppa.launchpad.net/marutter/rrutter/ubuntu trusty main" >> /etc/apt/sources.list \
    &&  gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys B04C661B \
    &&  gpg -a --export B04C661B | apt-key add - \
    &&  apt-get update \
    &&  apt-get install -y --no-install-recommends \
          r-base-dev \
          jags \
    && echo 'options(repos = list(CRAN = "https://cran.rstudio.com/"), unzip = "internal")' > /etc/R/Rprofile.site \
    && gdebi -n rstudio-server-$RSTUDIOVER-amd64.deb \
    && echo r-libs-user=$R_LIBS_USER >> /etc/rstudio/rsession.conf \
    && gdebi -n shiny-server-$SHINYVER-amd64.deb \
    && gdebi -n openbugs_${BUGSVER}_amd64.deb 
    
# Install Zonation
RUN    tar xzf zonation.tar.gz -C zonation

# Set locale
ENV LANG        en_US.UTF-8
ENV LANGUAGE    $LANG
RUN    echo "en_US "$LANG" UTF-8" >> /etc/locale.gen \
    && locale-gen en_US $LANG \ 
    && update-locale LANG=$LANG LANGUAGE=$LANG \
    && dpkg-reconfigure locales
ENV LC_ALL      $LANG

# Clean up
RUN    apt-get clean \
    && apt-get autoremove \
    && rm -rf \
         var/lib/apt/lists \
         julia-$JULIAVER-linux-x86_64.tar.gz \
         rstudio-server-$RSTUDIOVER-amd64.deb \
         shiny-server-$SHINYVER-amd64.deb \
         home/shiny \
         openbugs_${BUGSVER}_amd64.deb \
         zonation.tar.gz

# Copy scripts
COPY   supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY   userconf.sh /usr/bin/userconf.sh
COPY   jupyter_notebook_config.py jupyter_notebook_config.py
COPY   sshd_config /etc/ssh/sshd_config

# Config
RUN    chgrp staff /var/log/supervisor \
    && chmod g+w /var/log/supervisor \
    && chgrp staff /etc/supervisor/conf.d/supervisord.conf \
    && git config --system push.default simple \
    && git config --system url.'https://github.com/'.insteadOf git://github.com/

# Open ports
EXPOSE 8787
EXPOSE 3838
EXPOSE 8888
EXPOSE 22

# Start supervisor
CMD    supervisord