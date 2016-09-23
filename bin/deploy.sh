#!/bin/bash

# Exit immediately if any commands return non-zero
set -e

# cause a pipeline (for example, curl -s http://sipb.mit.edu/ | grep foo) to produce a
# failure return code if any command errors not just the last command of the pipeline.
set -o pipefail

# Output the commands we run
set -x

cf push qafire-sidekiq -f manifest-worker.yml

# Update the blue app
cf unmap-route qafire-blue apps.staging.digital.gov.au -n qafire
cf push qafire-blue -f manifest-web.yml
cf map-route qafire-blue apps.staging.digital.gov.au -n qafire

# Update the green app
cf unmap-route qafire-green apps.staging.digital.gov.au -n qafire
cf push qafire-green -f manifest-web.yml
cf map-route qafire-green apps.staging.digital.gov.au -n qafire

