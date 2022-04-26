#./transcrypt -F -c aes-256-cbc -p "foobar" -md SHA512 -sm configured --use_pbkdf2=0
./transcrypt -F -c aes-256-cbc -pbkdf2 -p "foobar" -md SHA512 -sm configured 

./transcrypt -d

transcrypt --uninstall -y
