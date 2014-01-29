echo
echo "Parando Redmine"
echo "Processos $(fuser 3833/tcp | tail -n 1 | xargs)"
echo
kill $(fuser 3833/tcp | tail -n 1 | xargs)
echo
echo "Reiniciando automaticamente"
echo
sleep 5
