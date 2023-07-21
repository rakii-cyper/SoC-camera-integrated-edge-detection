search_dir=./fp_input
read_dev=/dev/xillybus_read_32
write_dev=/dev/xillybus_write_32
for entry in "$search_dir"/*
do
  ./loopback $read_dev $write_dev $entry
done

