#!/bin/bash
#set -x
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

if [ "$#" -ne 1 ]
then
    echo "Missing name of Storage Bucket required to copy empty file"
    echo "Example: `basename "$0"` my_gcs_bucket"
    exit 1
fi

export BUCKET=$1
export DATA_FILE=borrow_data

while true
do
    date
    gsutil cp gs://$BUCKET/$DATA_FILE .
    sleep 30
done

