    {
      "apiVersion": "[variables('apiVersionDefault')]",
      "copy": {
        "count": "[variables('{{.Name}}Count')]",
        "name": "loop"
      },
      "dependsOn": [
{{if .IsCustomVNET}}
      "[variables('nsgID')]"
{{else}}
      "[variables('vnetID')]"
{{end}}
      ],
      "location": "[variables('location')]",
      "name": "[concat(variables('{{.Name}}VMNamePrefix'), 'nic-', copyIndex())]",
      "properties": {
{{if .IsCustomVNET}}
	    "networkSecurityGroup": {
		    "id": "[variables('nsgID')]"
	    },
{{end}}
        "ipConfigurations": [
          {
            "name": "ipconfig1",
            "properties": {
              "privateIPAllocationMethod": "Dynamic",
              "subnet": {
                "id": "[variables('{{.Name}}VnetSubnetID')]"
             }
            }
          }
        ],
        "enableIPForwarding": true
      },
      "type": "Microsoft.Network/networkInterfaces"
    },
{{if .IsManagedDisks}} 
   {
      "location": "[variables('location')]",
      "name": "[variables('{{.Name}}AvailabilitySet')]",
      "apiVersion": "[variables('apiVersionStorageManagedDisks')]",
      "properties":
        {
            "platformFaultDomainCount": "3",
            "platformUpdateDomainCount": "3",
		        "managed" : "true"
        },
  
      "type": "Microsoft.Compute/availabilitySets"
    },
{{else if .IsStorageAccount}}
    {
      "apiVersion": "[variables('apiVersionStorage')]",
      "copy": {
        "count": "[variables('{{.Name}}StorageAccountsCount')]",
        "name": "loop"
      },
      "dependsOn": [
        "[concat('Microsoft.Network/publicIPAddresses/', variables('masterPublicIPAddressName'))]"
      ],
      "location": "[variables('location')]",
      "name": "[concat(variables('storageAccountPrefixes')[mod(add(copyIndex(),variables('{{.Name}}StorageAccountOffset')),variables('storageAccountPrefixesCount'))],variables('storageAccountPrefixes')[div(add(copyIndex(),variables('{{.Name}}StorageAccountOffset')),variables('storageAccountPrefixesCount'))],variables('{{.Name}}AccountName'))]",
      "properties": {
        "accountType": "[variables('vmSizesMap')[variables('{{.Name}}VMSize')].storageAccountType]"
      },
      "type": "Microsoft.Storage/storageAccounts"
    },
    {{if .HasDisks}}
    {
      "apiVersion": "[variables('apiVersionStorage')]",
      "copy": {
        "count": "[variables('{{.Name}}StorageAccountsCount')]",
        "name": "datadiskLoop"
      },
      "dependsOn": [
        "[concat('Microsoft.Network/publicIPAddresses/', variables('masterPublicIPAddressName'))]"
      ],
      "location": "[variables('location')]",
      "name": "[concat(variables('storageAccountPrefixes')[mod(add(copyIndex(variables('dataStorageAccountPrefixSeed')),variables('{{.Name}}StorageAccountOffset')),variables('storageAccountPrefixesCount'))],variables('storageAccountPrefixes')[div(add(copyIndex(variables('dataStorageAccountPrefixSeed')),variables('{{.Name}}StorageAccountOffset')),variables('storageAccountPrefixesCount'))],variables('{{.Name}}DataAccountName'))]",
      "properties": {
        "accountType": "[variables('vmSizesMap')[variables('{{.Name}}VMSize')].storageAccountType]"
      },
      "type": "Microsoft.Storage/storageAccounts"
    },
    {{end}}
    {
      "location": "[variables('location')]",
      "name": "[variables('{{.Name}}AvailabilitySet')]",
      "apiVersion": "[variables('apiVersionDefault')]",
      "properties": {},
      "type": "Microsoft.Compute/availabilitySets"
    },
{{end}} 
  {
    {{if .IsManagedDisks}}
      "apiVersion": "[variables('apiVersionStorageManagedDisks')]",
    {{else}}
      "apiVersion": "[variables('apiVersionDefault')]",
    {{end}}
      "copy": {
        "count": "[variables('{{.Name}}Count')]",
        "name": "vmLoopNode"
      },
      "dependsOn": [
{{if .IsStorageAccount}}
        "[concat('Microsoft.Storage/storageAccounts/',variables('storageAccountPrefixes')[mod(add(div(copyIndex(),variables('maxVMsPerStorageAccount')),variables('{{.Name}}StorageAccountOffset')),variables('storageAccountPrefixesCount'))],variables('storageAccountPrefixes')[div(add(div(copyIndex(),variables('maxVMsPerStorageAccount')),variables('{{.Name}}StorageAccountOffset')),variables('storageAccountPrefixesCount'))],variables('{{.Name}}AccountName'))]",

  {{if .HasDisks}}
        "[concat('Microsoft.Storage/storageAccounts/',variables('storageAccountPrefixes')[mod(add(add(div(copyIndex(),variables('maxVMsPerStorageAccount')),variables('{{.Name}}StorageAccountOffset')),variables('dataStorageAccountPrefixSeed')),variables('storageAccountPrefixesCount'))],variables('storageAccountPrefixes')[div(add(add(div(copyIndex(),variables('maxVMsPerStorageAccount')),variables('{{.Name}}StorageAccountOffset')),variables('dataStorageAccountPrefixSeed')),variables('storageAccountPrefixesCount'))],variables('{{.Name}}DataAccountName'))]",
  {{end}}
{{end}}
        "[concat('Microsoft.Network/networkInterfaces/', variables('{{.Name}}VMNamePrefix'), 'nic-', copyIndex())]",
        "[concat('Microsoft.Compute/availabilitySets/', variables('{{.Name}}AvailabilitySet'))]"
      ],
      "tags":
      {
        "creationSource" : "[concat('acsengine-', variables('{{.Name}}VMNamePrefix'), copyIndex())]"
      },
      "location": "[variables('location')]",
      "name": "[concat(variables('{{.Name}}VMNamePrefix'), copyIndex())]",
      "properties": {
        "availabilitySet": {
          "id": "[resourceId('Microsoft.Compute/availabilitySets',variables('{{.Name}}AvailabilitySet'))]"
        },
        "hardwareProfile": {
          "vmSize": "[variables('{{.Name}}VMSize')]"
        },
        "networkProfile": {
          "networkInterfaces": [
            {
              "id": "[resourceId('Microsoft.Network/networkInterfaces',concat(variables('{{.Name}}VMNamePrefix'), 'nic-', copyIndex()))]"
            }
          ]
        },
        "osProfile": {
          "adminUsername": "[variables('username')]",
          "computername": "[concat(variables('{{.Name}}VMNamePrefix'), copyIndex())]",
          {{GetKubernetesAgentCustomData}}
          "linuxConfiguration": {
              "disablePasswordAuthentication": "true",
              "ssh": {
                "publicKeys": [
                  {
                    "keyData": "[parameters('sshRSAPublicKey')]",
                    "path": "[variables('sshKeyPath')]"
                  }
                ]
              }
            }
            {{if HasLinuxSecrets}}
              ,
              "secrets": "[variables('linuxProfileSecrets')]"
            {{end}}
        },
        "storageProfile": {
          {{GetDataDisks .}}
          "imageReference": {
            "offer": "[variables('osImageOffer')]",
            "publisher": "[variables('osImagePublisher')]",
            "sku": "[variables('osImageSKU')]",
            "version": "[variables('osImageVersion')]"
          }
          {{if .IsStorageAccount}}
          ,
          "osDisk": {
            "caching": "ReadWrite",
            "createOption": "FromImage",
            "name": "[concat(variables('{{.Name}}VMNamePrefix'), copyIndex(),'-osdisk')]",
            "vhd": {
              "uri": "[concat(reference(concat('Microsoft.Storage/storageAccounts/',variables('storageAccountPrefixes')[mod(add(div(copyIndex(),variables('maxVMsPerStorageAccount')),variables('{{.Name}}StorageAccountOffset')),variables('storageAccountPrefixesCount'))],variables('storageAccountPrefixes')[div(add(div(copyIndex(),variables('maxVMsPerStorageAccount')),variables('{{.Name}}StorageAccountOffset')),variables('storageAccountPrefixesCount'))],variables('{{.Name}}AccountName')),variables('apiVersionStorage')).primaryEndpoints.blob,'osdisk/', variables('{{.Name}}VMNamePrefix'), copyIndex(), '-osdisk.vhd')]"
            }
          }
          {{end}}
        }
      },
      "type": "Microsoft.Compute/virtualMachines"
    },
    {
      "apiVersion": "[variables('apiVersionDefault')]",
      "copy": {
        "count": "[variables('{{.Name}}Count')]",
        "name": "vmLoopNode"
      },
      "dependsOn": [
        "[concat('Microsoft.Compute/virtualMachines/', variables('{{.Name}}VMNamePrefix'), copyIndex())]"
      ],
      "location": "[variables('location')]",
      "type": "Microsoft.Compute/virtualMachines/extensions",
      "name": "[concat(variables('{{.Name}}VMNamePrefix'), copyIndex(),'/cse', copyIndex())]",
      "properties": {
        "publisher": "Microsoft.OSTCExtensions",
        "type": "CustomScriptForLinux",
        "typeHandlerVersion": "1.5",
        "autoUpgradeMinorVersion": true,
        "settings": {},
        "protectedSettings": {
          "commandToExecute": "[concat('/usr/bin/nohup /bin/bash -c \"/bin/bash /opt/azure/containers/provision.sh ',variables('tenantID'),' ',variables('subscriptionId'),' ',variables('resourceGroup'),' ',variables('location'),' ',variables('subnetName'),' ',variables('nsgName'),' ',variables('virtualNetworkName'),' ',variables('routeTableName'),' ',variables('primaryAvailablitySetName'),' ',variables('servicePrincipalClientId'),' ',variables('servicePrincipalClientSecret'),' ',variables('clientPrivateKey'),' ',variables('targetEnvironment'),' >> /var/log/azure/cluster-provision.log 2>&1 &\" &')]"
        }
      }
    }
