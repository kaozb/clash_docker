FROM ubuntu

RUN apt update && apt install curl -y && rm -rf /var/cache/apt

ADD . /root/

RUN chmod +x /root/endpoint.sh

CMD /root/endpoint.sh
