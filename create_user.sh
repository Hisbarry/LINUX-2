#!/bin/bash

# Set the log file and password file
LOG_FILE=/var/log/user_management.log
PASSWORD_FILE=/var/secure/user_passwords.txt

# Check if the input file is provided
if [ $# -ne 1 ]; then
  echo "Usage: $0 <input_file>"
  exit 1
fi

# Read the input file
INPUT_FILE=$1

# Create the log file and password file if they don't exist
touch $LOG_FILE
chmod 600 $LOG_FILE
touch $PASSWORD_FILE
chmod 600 $PASSWORD_FILE

# Ensure the pwgen tool is installed
if ! command -v pwgen &> /dev/null; then
  echo "pwgen could not be found, please install it." | tee -a $LOG_FILE
  exit 1
fi

# Iterate over each line in the input file
while IFS=';' read -r user groups; do
  # Remove whitespace from the user and groups
  user=$(echo "$user" | tr -d '[:space:]')
  groups=$(echo "$groups" | tr -d '[:space:]')

  # Check if user already exists
  if id "$user" &> /dev/null; then
    echo "User $user already exists, skipping." | tee -a $LOG_FILE
    continue
  fi

  # Create the user's personal group, handle if it exists
  if ! groupadd $user; then
    echo "Group $user already exists or failed to create." | tee -a $LOG_FILE
  fi

  # Create the user and add them to their personal group
  if ! useradd -m -g $user -s /bin/bash $user; then
    echo "Failed to create user $user." | tee -a $LOG_FILE
    continue
  fi

  # Add the user to the specified groups
  IFS=',' read -r -a group_array <<< "$groups"
  for group in "${group_array[@]}"; do
    if ! grep -q "^$group:" /etc/group; then
      if ! groupadd $group; then
        echo "Failed to create group $group for user $user." | tee -a $LOG_FILE
      fi
    fi
    if ! usermod -aG $group $user; then
      echo "Failed to add user $user to group $group." | tee -a $LOG_FILE
    fi
  done

  # Generate a random password for the user
  password=$(pwgen -s 12 1)

  # Set the user's password
  echo "$user:$password" | chpasswd

  # Log the action
  echo "Created user $user with password $password and added to groups ${group_array[*]}" >> $LOG_FILE

  # Store the password securely
  echo "$user,$password" >> $PASSWORD_FILE

done < $INPUT_FILE

echo "User creation process completed. Check $LOG_FILE for details."
