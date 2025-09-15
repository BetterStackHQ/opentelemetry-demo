#!/usr/bin/env ruby

require 'yaml'

# Services to keep
KEEP_SERVICES = %w[
  accounting ad cart checkout currency email
  fraud-detection frontend frontend-proxy image-provider
  load-generator payment product-catalog quote
  recommendation shipping flagd flagd-ui kafka
  postgres postgresql valkey-cart
].freeze

# Resources to remove (observability stack)
REMOVE_SERVICES = %w[
  opensearch grafana jaeger prometheus
  otel-collector opentelemetry-collector
].freeze

def should_keep_resource?(resource)
  return false unless resource.is_a?(Hash)

  kind = resource['kind'] || ''
  metadata = resource['metadata'] || {}
  name = metadata['name'] || ''

  # Always keep namespace
  return true if kind == 'Namespace'

  # Check if it's an observability component to remove
  REMOVE_SERVICES.each do |remove_pattern|
    return false if name.include?(remove_pattern)
  end

  # Keep main service account
  return true if kind == 'ServiceAccount' && name == 'opentelemetry-demo'

  # Keep flagd and product catalog configs
  return true if kind == 'ConfigMap' && ['flagd-config', 'product-catalog-products'].include?(name)

  # For Services, Deployments, StatefulSets - check if in keep list
  if %w[Service Deployment StatefulSet].include?(kind)
    KEEP_SERVICES.each do |keep_svc|
      return true if name == keep_svc || name.start_with?("#{keep_svc}-")
    end
    return false
  end

  # Skip other resources by default (RBAC, etc.)
  false
end

def clean_deployment(deployment, service_name)
  # Update container images and remove OTEL env vars
  if deployment['spec'] && deployment['spec']['template'] &&
     deployment['spec']['template']['spec'] && deployment['spec']['template']['spec']['containers']

    deployment['spec']['template']['spec']['containers'].each do |container|
      # Update image reference
      if container['image'] && container['image'].include?('ghcr.io/open-telemetry/demo')
        container['image'] = "betterstack/opentelemetry-demo:latest-#{service_name}"
      end

      # Remove OTEL environment variables
      if container['env']
        container['env'] = container['env'].reject do |env|
          env['name'] && env['name'].start_with?('OTEL_')
        end
      end
    end
  end

  deployment
end

def main
  input_file = 'kubernetes/opentelemetry-demo.yaml'
  output_file = 'kubernetes/opentelemetry-demo-cleaned.yaml'

  puts "Reading #{input_file}..."

  # Read all YAML documents
  documents = []
  File.open(input_file, 'r') do |file|
    YAML.load_stream(file) do |doc|
      documents << doc if doc
    end
  end

  puts "Found #{documents.length} resources"

  # Filter and clean resources
  cleaned_docs = []
  kept_count = 0
  removed_count = 0

  documents.each do |doc|
    next unless doc

    if should_keep_resource?(doc)
      # Clean deployments
      if doc['kind'] == 'Deployment'
        service_name = doc['metadata']['name']
        doc = clean_deployment(doc, service_name)
      end

      cleaned_docs << doc
      kept_count += 1
      puts "  Keeping: #{doc['kind'] || 'Unknown'} - #{doc.dig('metadata', 'name') || 'unnamed'}"
    else
      removed_count += 1
      kind = doc['kind'] || 'Unknown'
      name = doc.dig('metadata', 'name') || 'unnamed'
      if REMOVE_SERVICES.any? { |obs| name.include?(obs) }
        puts "  Removing: #{kind} - #{name}"
      end
    end
  end

  puts "\nKept #{kept_count} resources, removed #{removed_count} resources"

  # Write cleaned manifest
  puts "\nWriting cleaned manifest to #{output_file}..."
  File.open(output_file, 'w') do |file|
    file.puts "# Copyright The OpenTelemetry Authors"
    file.puts "# SPDX-License-Identifier: Apache-2.0"
    file.puts "# Cleaned version without observability stack"

    cleaned_docs.each_with_index do |doc, index|
      file.puts "---"
      yaml_output = doc.to_yaml
      # Remove the leading --- that to_yaml adds
      yaml_output = yaml_output.sub(/\A---\s*\n/, '')
      file.puts yaml_output
    end
  end

  puts "Done! Cleaned manifest saved to #{output_file}"
end

main if __FILE__ == $0
