#!/bin/sh

if [ "$1" = 'chat_app' ]; then
    python -m chainlit run chat_app.py -h
elif [ "$1" = 'indexer_job' ]; then
    python indexer_job.py
else
    echo "Invalid startup argument"
fi