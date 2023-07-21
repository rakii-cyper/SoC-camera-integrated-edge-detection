g++ read_fifo_to_cam.cpp -o fifo_to_cam `pkg-config --cflags --libs opencv`
g++ read_cam_to_fifo.cpp -o cam_to_fifo `pkg-config --cflags --libs opencv`
