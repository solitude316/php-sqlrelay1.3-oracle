FROM centos:latest

RUN yum update -y
RUN yum -y install gcc-c++ make libaio libxml2-devel openssl openssl-libs openssl-devel \
	icu libicu libicu-devel readline-devel bzip2 bzip2-devel unzip sudo file nc

COPY ./configs/curl-7.60.0.tar.gz /tmp/
RUN cd /tmp && tar zxf curl-7.60.0.tar.gz
RUN LDFLAGS=-R/usr/include/openssl/
RUN cd /tmp/curl-7.60.0/ && /tmp/curl-7.60.0/configure --prefix=/usr/ --with-ssl=/usr/
RUN cd /tmp/curl-7.60.0/ && make
RUN cd /tmp/curl-7.60.0/ && make install

COPY ./configs/php-7.2.6.tar.gz /tmp/
RUN cd /tmp/ && tar zxf php-7.2.6.tar.gz

RUN cd /tmp/php-7.2.6 && /tmp/php-7.2.6/configure --prefix=/usr/local \
	--sysconfdir=/etc \
	--localstatedir=/var \
	--datadir=/usr/share/php \
	--mandir=/usr/share/man \
	--with-config-file-path=/etc \
	--with-zlib \
	--enable-bcmath \
	--with-bz2 \
	--enable-calendar \
	--with-gettext=/usr \
	--enable-mbstring \
	--with-readline \
	--with-curl=/tmp/curl-7.60.0 \
	--with-openssl \
	--with-openssl-dir=/usr/include/ \
	--enable-intl \
	--enable-zip \
	--enable-libxml \
	--with-config-file-scan-dir=/usr/local/etc/php/conf.d

RUN cd /tmp/php-7.2.6 && make
RUN cd /tmp/php-7.2.6 && make install
RUN mkdir -p /usr/local/etc/php/conf.d

COPY ./configs/instantclient-basic-linux.x64-12.2.0.1.0-2.zip /tmp
COPY ./configs/instantclient-sdk-linux.x64-12.2.0.1.0.zip /tmp
RUN cd /tmp && unzip instantclient-basic-linux.x64-12.2.0.1.0-2.zip && unzip instantclient-sdk-linux.x64-12.2.0.1.0.zip
RUN mv /tmp/instantclient_12_2 /usr/local/
RUN echo '/usr/local/instantclient_12_2' > /etc/ld.so.conf.d/oracle.conf && ldconfig

COPY ./configs/rudiments-1.0.7.tar.gz /tmp/
COPY ./configs/sqlrelay-1.3.0.tar.gz /tmp/

RUN cd /tmp && tar zxf /tmp/rudiments-1.0.7.tar.gz && cd /tmp/rudiments-1.0.7
RUN cp -rf /tmp/php-7.2.6/scripts /tmp/rudiments-1.0.7/
RUN cd /tmp/rudiments-1.0.7 && /tmp/rudiments-1.0.7/configure
RUN cd /tmp/rudiments-1.0.7 && make 
RUN cd /tmp/rudiments-1.0.7 && make install

RUN cd /tmp && tar zxf /tmp/sqlrelay-1.3.0.tar.gz
RUN cp -rf /tmp/php-7.2.6/scripts /tmp/sqlrelay-1.3.0/
RUN cd /tmp/sqlrelay-1.3.0/ && /tmp/sqlrelay-1.3.0/configure --with-php-prefix=/usr/local/
RUN cd /tmp/sqlrelay-1.3.0/ && make
RUN cd /tmp/sqlrelay-1.3.0/ && make install

RUN sed -i '/secure_path/ s/\(\/sbin:\/bin:\/usr\/sbin:\/usr\/bin\)/\1:\/usr\/local\/firstworks\/bin/g' /etc/sudoers
RUN echo '/usr/local/firstworks/lib' > /etc/ld.so.conf.d/firstworks.conf && ldconfig
RUN echo 'export PATH=$PATH:/usr/local/firstworks/bin' > /etc/profile.d/firstworks.sh
RUN echo 'extension=pdo_sqlrelay.so' > /usr/local/etc/php/conf.d/pdo_sqlrelay.ini

RUN cd /tmp rm -rf /tmp/php-7.2.6 /tmp/php-7.2.6.tar.gz \
	/tmp/rudiments-1.0.7.tar.gz /tmp/rudiments-1.0.7 \
	/tmp/sqlrelay-1.3.0.tar.gz /tmp/sqlrelay-1.3.0/

COPY ./configs/sqlrelay.conf /usr/local/firstworks/etc/sqlrelay.conf.d/
RUN sudo chown -R nobody /usr/local/firstworks/etc/sqlrelay.conf.d/
RUN sudo chmod -R 640 /usr/local/firstworks/etc/sqlrelay.conf.d/

COPY ./configs/sqlrelay-start.sh /usr/local/etc/
RUN chmod +x /usr/local/etc/sqlrelay-start.sh

RUN curl https://bootstrap.pypa.io/get-pip.py | python
RUN pip install supervisor
RUN mkdir -p /var/log/supervisor && \
	mkdir -p /etc/supervisor/
COPY ./configs/supervisor.conf /etc/supervisor/

CMD ["supervisord", "-c", "/etc/supervisor/supervisor.conf"]
