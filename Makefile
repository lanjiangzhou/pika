
include Makefile.global
#RPATH = /usr/local/pika21/lib/
#LFLAGS = -Wl,-rpath=$(RPATH)


UNAME := $(shell if [ -f "/etc/redhat-release" ]; then echo "CentOS"; else echo "Ubuntu"; fi)

OSVERSION := $(shell cat /etc/redhat-release | cut -d "." -f 1 | awk '{print $$NF}')

ifeq ($(UNAME), Ubuntu)
  SO_DIR = $(CURDIR)/lib/ubuntu
  TOOLS_DIR = $(CURDIR)/tools/ubuntu
else ifeq ($(OSVERSION), 5)
  SO_DIR = $(CURDIR)/lib/5.4
  TOOLS_DIR = $(CURDIR)/tools/5.4
else
  SO_DIR = $(CURDIR)/lib/6.2
  TOOLS_DIR = $(CURDIR)/tools/6.2
endif

CXX = g++

ifeq ($(__REL), 1)
#CXXFLAGS = -Wall -W -DDEBUG -g -O0 -D__XDEBUG__ -fPIC -Wno-unused-function -std=c++11
	CXXFLAGS = -O2 -g -pipe -fPIC -W -DNDEBUG -Wwrite-strings -Wpointer-arith -Wreorder -Wswitch -Wsign-promo -Wredundant-decls -Wformat -Wall -Wno-unused-parameter -D_GNU_SOURCE -D__STDC_FORMAT_MACROS -DROCKSDB_PLATFORM_POSIX -DROCKSDB_LIB_IO_POSIX  -DOS_LINUX -std=c++11 -gdwarf-2 -Wno-redundant-decls
else
	CXXFLAGS = -O0 -g -pg -pipe -fPIC -W -DDEBUG -Wwrite-strings -Wpointer-arith -Wreorder -Wswitch -Wsign-promo -Wredundant-decls -Wformat -Wall -Wno-unused-parameter -D_GNU_SOURCE -D__STDC_FORMAT_MACROS -DROCKSDB_PLATFORM_POSIX -DROCKSDB_LIB_IO_POSIX  -DOS_LINUX -std=c++11 -Wno-redundant-decls
endif

OBJECT = pika
SRC_DIR = ./src
THIRD_PATH = $(CURDIR)/third
OUTPUT = ./output
dummy := $(shell ("$(CURDIR)/detect_tcmalloc" "$(CURDIR)/make_config.mk"))
include make_config.mk

INCLUDE_PATH = -I./include/ \
			   -I./src/ \
			   -I$(THIRD_PATH)/glog/src/ \
			   -I$(THIRD_PATH)/nemo/output/include/ \
				 -I$(THIRD_PATH)/nemo/3rdparty/nemo-rocksdb/rocksdb/ \
				 -I$(THIRD_PATH)/nemo/3rdparty/nemo-rocksdb/rocksdb/include \
			   -I$(THIRD_PATH)/slash \
			   -I$(THIRD_PATH)/pink \

LIB_PATH = -L./ \
		   -L$(THIRD_PATH)/nemo/output/lib/ \
		   -L$(THIRD_PATH)/slash/slash/lib/ \
		   -L$(THIRD_PATH)/pink/pink/lib/ \
		   -L$(THIRD_PATH)/glog/.libs/


LIBS = -lpthread \
	   -lglog \
	   -lnemo \
		 -lnemodb \
	   -lslash \
	   -lrocksdb \
		 -lpink \
	   -lz \
	   -lbz2 \
	   -lsnappy \
	   -lrt 

LIBS += $(TCMALLOC_LDFLAGS)
CXXFLAGS += $(TCMALLOC_EXTENSION_FLAGS)

NEMO = $(THIRD_PATH)/nemo/output/lib/libnemo.a
GLOG = $(SO_DIR)/libglog.so.0
PINK = $(THIRD_PATH)/pink/lib/libpink.a
SLASH = $(THIRD_PATH)/slash/lib/libslash.a

.PHONY: all clean


BASE_OBJS := $(wildcard $(SRC_DIR)/*.cc)
BASE_OBJS += $(wildcard $(SRC_DIR)/*.c)
BASE_OBJS += $(wildcard $(SRC_DIR)/*.cpp)
OBJS = $(patsubst %.cc,%.o,$(BASE_OBJS))


all: $(OBJECT)
	@echo "UNAME    : $(UNAME)"
	@echo "SO_DIR   : $(SO_DIR)"
	@echo "TOOLS_DIR: $(TOOLS_DIR)"
	make -C $(CURDIR)/tools/aof_to_pika/
	cp $(CURDIR)/tools/aof_to_pika/output/bin/* $(TOOLS_DIR)
	make __REL=1 -C $(CURDIR)/tools/binlog_sync/
	cp $(CURDIR)/tools/binlog_sync/binlog_sync $(TOOLS_DIR)
	make __REL=1 -C $(CURDIR)/tools/binlog_tools/
	cp $(CURDIR)/tools/binlog_tools/binlog_sender $(TOOLS_DIR)
	cp $(CURDIR)/tools/binlog_tools/binlog_parser $(TOOLS_DIR)
	rm -rf $(OUTPUT)
	mkdir $(OUTPUT)
	mkdir $(OUTPUT)/bin
	cp -r ./conf $(OUTPUT)/
	mkdir $(OUTPUT)/lib
	cp -r $(SO_DIR)/*  $(OUTPUT)/lib
	cp $(OBJECT) $(OUTPUT)/bin/
	mkdir $(OUTPUT)/tools
	if [ -d $(TOOLS_DIR) ]; then \
		cp -r $(TOOLS_DIR)/* $(OUTPUT)/tools/; \
	fi
	rm -rf $(OBJECT)
	@echo "Success, go, go, go..."


$(OBJECT): $(NEMO) $(GLOG) $(PINK) $(SLASH) $(OBJS)
	$(CXX) $(CXXFLAGS) -o $@ $(OBJS) $(INCLUDE_PATH) $(LIB_PATH)  $(LFLAGS) $(LIBS) 

$(NEMO):
	make -C $(THIRD_PATH)/nemo/

$(SLASH):
	make -C $(THIRD_PATH)/slash/slash/

$(PINK):
	make -C $(THIRD_PATH)/pink/pink/ SLASH_PATH=$(THIRD_PATH)/slash

$(OBJS): %.o : %.cc
	$(CXX) $(CXXFLAGS) -c $< -o $@ $(INCLUDE_PATH) 

$(TOBJS): %.o : %.cc
	$(CXX) $(CXXFLAGS) -c $< -o $@ $(INCLUDE_PATH) 

$(GLOG):
	#cd $(THIRD_PATH)/glog; ./configure; make; echo '*' > $(CURDIR)/third/glog/.gitignore; cp $(CURDIR)/third/glog/.libs/libglog.so.0 $(SO_DIR);
	cd $(THIRD_PATH)/glog; if [ ! -f ./Makefile ]; then ./configure; fi; make; echo '*' > $(CURDIR)/third/glog/.gitignore; cp $(CURDIR)/third/glog/.libs/libglog.so.0 $(SO_DIR);

clean: 
	rm -rf $(SRC_DIR)/*.o
	rm -rf $(OUTPUT)/*
	rm -rf $(OUTPUT)
	rm -rf $(CURDIR)/make_config.mk
	
distclean: 
	rm -rf $(SRC_DIR)/*.o
	rm -rf $(OUTPUT)/*
	rm -rf $(OUTPUT)
	rm -rf $(CURDIR)/make_config.mk
	make distclean -C $(THIRD_PATH)/nemo/3rdparty/nemo-rocksdb/
	make clean -C $(THIRD_PATH)/nemo/
	make clean -C $(THIRD_PATH)/pink/pink
	make clean -C $(THIRD_PATH)/slash/slash
	make distclean -C $(THIRD_PATH)/glog/
	make clean -C $(CURDIR)/tools/aof_to_pika
	make clean -C $(CURDIR)/tools/pika_monitor
	make clean -C $(CURDIR)/tools/binlog_sync
	make clean -C $(CURDIR)/tools/binlog_tools
	rm -rf $(TOOLS_DIR)/aof_to_pika
	rm -rf $(TOOLS_DIR)/binlog_sync
	rm -rf $(TOOLS_DIR)/binlog_parser
	rm -rf $(TOOLS_DIR)/binlog_sender
	rm -rf $(SO_DIR)/libglog.so*

