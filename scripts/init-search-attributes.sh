#!/bin/bash

# Script untuk inisialisasi search attributes yang diperlukan PeerDB
# File: scripts/init-search-attributes.sh

echo "Waiting for Temporal server to be ready..."

# Tunggu hingga Temporal server ready
until tctl cluster health; do
  echo "Temporal server not ready, waiting..."
  sleep 5
done

echo "Temporal server is ready. Initializing search attributes..."

# Fungsi untuk menambahkan search attribute dengan pengecekan
add_search_attribute() {
  local name=$1
  local type=$2
  
  echo "Checking if search attribute $name exists..."
  
  # Cek apakah search attribute sudah ada
  if tctl --namespace default admin cluster get-search-attributes | grep -q "$name"; then
    echo "Search attribute $name already exists, skipping..."
  else
    echo "Adding search attribute: $name ($type)"
    echo 'Y' | tctl --namespace default admin cluster add-search-attributes --name "$name" --type "$type"
    if [ $? -eq 0 ]; then
      echo "Successfully added search attribute: $name"
    else
      echo "Failed to add search attribute: $name"
    fi
  fi
}

# Tambahkan search attributes yang diperlukan PeerDB
add_search_attribute "MirrorName" "Text"
add_search_attribute "FlowJobType" "Keyword"
add_search_attribute "SourcePeer" "Keyword"
add_search_attribute "TargetPeer" "Keyword"

echo "Search attributes initialization completed!"

# Verifikasi search attributes yang telah ditambahkan
echo "Current search attributes:"
tctl --namespace default admin cluster get-search-attributes | grep -E "(MirrorName|FlowJobType|SourcePeer|TargetPeer)"

echo "Keeping container running for workflow operations..."
# Jalankan script mirror-name-search.sh untuk keep container alive
exec /etc/temporal/entrypoint.sh
