#!/bin/bash

user_name="10.20.1.2"
if [ -n "${USER_NAME}" ]; then
    user_name=${USER_NAME}
fi

su - ${user_name}
