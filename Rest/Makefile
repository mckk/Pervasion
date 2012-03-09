MAIN=uk.ac.imperial.doc.rest.MsgReader

INPUT=uk.ac.imperial.doc.rest.SerialMsg -comm serial@/dev/ttyUSB1:micaz

all: clean build

clean:
	mvn clean

build: install-tinyos
	mvn package
	
run:
	mvn exec:java -Dexec.mainClass="$(MAIN)"  -Dexec.args="$(INPUT)"
	
install-tinyos:
	mvn install:install-file -Dfile=lib/tinyos.jar \
                         -DgroupId=net.tinyos \
                         -DartifactId=tinyos-java \
                         -Dversion=2.1 \
                         -Dpackaging=jar \
                         -DlocalRepositoryPath=./local-repo
