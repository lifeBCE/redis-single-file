redis-cli --scan --pattern '*' | while read key; do
  ttl=$(redis-cli ttl $key)
  if [ $ttl -eq -2 ]; then
    echo "Key $key has expired"
  else
    echo "Key $key has NOT expired"
  fi
done
