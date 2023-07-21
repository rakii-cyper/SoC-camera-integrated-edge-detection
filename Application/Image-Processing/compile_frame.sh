g++ read_fifo_to_img.cpp -o fifo_to_img `pkg-config --cflags --libs opencv`
g++ read_img_to_fifo.cpp -o img_to_fifo `pkg-config --cflags --libs opencv`
