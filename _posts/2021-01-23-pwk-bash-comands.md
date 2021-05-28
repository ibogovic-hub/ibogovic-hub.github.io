---
title: Bash Commands
tags: PWK
---

## list all running services

```bash
systemctl list-unit-files
```

## listing, adding and removing tools

```bash
apt-cache search pure-ftpd
apt show pure-ftpd | less
```

## reading user input

```bash
#! /bin/bash  
echo “Hello there, would you like to learn how to hack: Y/N ?”  
read answer  
echo “Your answer was $answer
```  

## reading user input 02

```bash
#! /bin/bash
# prompt the user for credencials

read -p ‘Username:  ’ username
read -sp ‘Password: ’ password

echo “Thanks, your creds are as follows: ”  $username ” and “ $password
```

## if, else, elif statements

> → if.sh

```bash
#! /bin/bash
# if statement example

read -p “What is you age: ” age

if [ age -lt 16 ]
then
    echo “You might need parental permission to take this course!”
fi
```

> → else.sh
```bash
#! /bin/bash
# else statement example

read -p “What is you age: ” age

if [ $age -lt 16 ]
then
    echo “You might need parental permission to take this course!”
else
    echo “Welcome to the course”
fi
```

> → elif.sh
```bash
#! /bin/bash
# else statement example

read -p “What is you age: ” age

if [ $age -lt 16 ]
then
    echo “You might need parental permission to take this course!”
elif
    [ $age -gt 60 ]
then
    echo “Hats off to you, respect!”
else
    echo “Welcome to the course”
fi
```

## for loops

> → one liner
```bash
for ip in $(seq 1 25); do echo 10.11.1.$ip; done
```

> → one liner sequence expression  
```bash
for i in {1..254}; do echo 10.11.1.$i; done
```

## while loops

```bash
#! /bin/bash
# while loop example

counter = 1
while [ $counter -le 10 ]
do
    echo “10.11.1.$counter”
    ((counter++))
done
```

## functions

```bash
#! /bin/bash
# function example

print_me () {
    echo “You have been printed!”
}

print_me
```

> → with argument
```bash
#! /bin/bash
# passing argument to the function

pass_arg () {
    echo “Today's random number is: $1”
}

pass_arg $RANDOM
```

> → return value example  
```bash
#! /bin/bash
# function return value example

return_me () {
    echo “Oh hello there, I'm returning a random value!”
    return $RANDOM
}

return_me
echo “The previous function returned a value of $?”
```
