FROM ubuntu

RUN apt update && apt install curl -y

ADD . /root/

RUN chmod +x /root/endpoint.sh

CMD /root/endpoint.sh
