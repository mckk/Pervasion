SRC_PACKAGE=uk.ac.imperial.doc.rest
SRC_DIR=src/main/java/uk/ac/imperial/doc/rest

MAIN=$(SRC_PACKAGE).MsgReader
INPUT=$(SRC_PACKAGE).SerialMsg -comm serial@/dev/ttyUSB1:micaz

all: serial build 	

clean:
	mvn clean
	rm -f $(SRC_DIR)/SerialMsg.java

build: install
	mvn package
	
run:
	mvn exec:java -Dexec.mainClass="$(MAIN)"  -Dexec.args="$(INPUT)"

serial:
	mig java -java-classname=SerialMsg ../Receiver/SerialMsg.h SerialMsg -o $(SRC_DIR)/SerialMsg.java
	cp $(SRC_DIR)/SerialMsg.java $(SRC_DIR)/Temp.java
	(echo "package $(SRC_PACKAGE);\n" ; cat $(SRC_DIR)/Temp.java) > $(SRC_DIR)/SerialMsg.java
	rm -f $(SRC_DIR)/Temp.java 
	
install:
	mvn install:install-file -Dfile=lib/tinyos.jar \
                         -DgroupId=net.tinyos \
                         -DartifactId=tinyos-java \
                         -Dversion=2.1 \
                         -Dpackaging=jar \
                         -DlocalRepositoryPath=./local-repo
