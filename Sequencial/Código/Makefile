CC = gcc

CFLAGS = -O3

LIBS = -lm

TARGET = bin/programa

SRC = sequencial.c generate.c

all: $(TARGET)

$(TARGET): $(SRC)
	mkdir -p bin
	$(CC) $(CFLAGS) $(SRC) -o $(TARGET) $(LIBS)

clean:
	rm -rf bin outputs resultados logs
