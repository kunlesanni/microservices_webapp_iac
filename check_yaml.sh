#!/bin/bash

echo "🔍 Checking YAML files for syntax issues..."

TEMP_DIR=$(mktemp -d)
cp -r k8s/* $TEMP_DIR/

# Replace placeholders with sample values for validation
find $TEMP_DIR -name "*.yaml" -type f | while read file; do
    sed -i.bak \
        -e "s/{{ACR_NAME}}/acrpyreactdev/g" \
        -e "s/{{IMAGE_TAG}}/50e620e/g" \
        -e "s/{{ENVIRONMENT}}/dev/g" \
        -e "s/{{PROJECT_NAME}}/pyreact/g" \
        "$file"
    rm -f "$file.bak"
done

echo "📋 Validating YAML files..."

# Check each YAML file
find $TEMP_DIR -name "*.yaml" -type f | while read file; do
    filename=$(basename "$file")
    relative_path=${file#$TEMP_DIR/}
    
    if kubectl apply -f "$file" --dry-run=client &> /dev/null; then
        echo "✅ $relative_path - Valid"
    else
        echo "❌ $relative_path - Invalid"
        echo "   Error details:"
        kubectl apply -f "$file" --dry-run=client 2>&1 | head -3 | sed 's/^/     /'
        echo ""
    fi
done

# Clean up
rm -rf $TEMP_DIR

echo ""
echo "🔍 Common issues to check:"
echo "  1. YAML indentation (use spaces, not tabs)"
echo "  2. Missing quotes around values with special characters"
echo "  3. Deprecated Kubernetes resources (PodSecurityPolicy)"
echo "  4. Invalid environment variable syntax"
echo ""
echo "💡 Run this script to identify specific YAML syntax errors before deployment."