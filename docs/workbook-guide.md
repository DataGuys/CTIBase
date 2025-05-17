# MDE Indicator Management Workbook Guide

This guide explains how to use the MDE Indicator Management Workbook included in this solution.

## Overview

The workbook provides a dashboard for viewing and managing Microsoft Defender for Endpoint (MDE) threat indicators. Key features include:

- Visual summaries of indicator types and sources
- Complete listing of all indicators with filtering and sorting
- Forms for adding and updating indicators
- Flagging indicators that were added directly in MDE

## Viewing Indicators

### Dashboard

The dashboard at the top of the workbook displays:

- **Indicator Types**: Pie chart showing distribution by type (IP, URL, File Hash, etc.)
- **Indicator Source**: Breakdown of indicators added via MDE or via this workbook

### Indicator List

The comprehensive indicator list shows all indicators in a grid with columns for:

- Indicator Value (the actual IP, URL, or file hash)
- Indicator Type
- Action (Alert, Block, etc.)
- Title and Description
- Severity and Confidence
- TLP Level
- Created By and Expiration Date
- Source flags (directlyAddedToMDE, modifiedInLogAnalytics)

You can filter and sort this grid by any column.

## Managing Indicators

### Adding New Indicators

To add a new indicator:

1. Scroll to the "Add New Indicator" section
2. Fill in the required fields:
   - Indicator Value: The actual URL, IP, file hash, etc.
   - Indicator Type: Select from the dropdown
   - Action: What MDE should do (Alert, Block, etc.)
   - Title: Short name for the indicator
   - Severity: How critical this indicator is
   - Additional fields as needed
3. Click "Run Query" to execute the generated KQL query
4. The indicator will be added to the Log Analytics table
5. The sync playbook will detect the change and update MDE accordingly

### Updating Existing Indicators

To update an existing indicator:

1. Find the indicator in the grid
2. Note its ID and current values
3. Use the "Update Indicator" form
4. Enter the ID and the fields you want to update
5. Click "Run Query" to execute the generated KQL
6. The indicator will be updated in both Log Analytics and MDE

### Working with Direct MDE Indicators

Indicators that were added directly in MDE (not through this workbook) are flagged with `directlyAddedToMDE = true`. These indicators:

- Are synchronized to the Log Analytics table
- Are displayed in the workbook with a special flag
- Can be updated like any other indicator
- Will remain synchronized in both systems

## Best Practices

1. **Use Tags**: Apply consistent tags to indicators for better organization
2. **Set Expiration Dates**: Always set appropriate expiration times to prevent stale indicators
3. **Document Sources**: Use the description field to document where the indicator came from
4. **Review Regularly**: Use the workbook to periodically review and clean up indicators

## Troubleshooting

If indicators aren't synchronizing properly:

1. Check that the Logic App runs are succeeding
2. Verify the app registration has the necessary permissions
3. Ensure the Managed Identity has access to the Key Vault
4. Check for errors in the Logic App runs

For additional help, refer to the GitHub repository documentation or open an issue.
