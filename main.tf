resource "azurerm_resource_group" "example" {
  name     = "example-resources"
  location = "West US"
}

resource "azurerm_virtual_network" "example" {
  name                = "example-vnet"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "example" {
  name                 = "example-subnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "example" {
  name                = "example-public-ip"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "example" {
  name                = "example-nic"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.example.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.example.id
  }
}

data "template_file" "cloud_init" {
  template = <<EOT
# cloud-config
package_upgrade: true
packages:
  - docker.io
  - apt-transport-https
  - ca-certificates
  - curl
  - software-properties-common
  - conntrack

runcmd:
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  - sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  - sudo apt-get update
  - sudo apt-get install -y kubelet kubeadm kubectl
  - sudo snap install minikube --classic
EOT
}

resource "azurerm_linux_virtual_machine" "example" {
  name                = "example-vm"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  size                = "Standard_DS1_v2"

  admin_username      = "adminuser"
  disable_password_authentication = true
  
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  network_interface_ids = [azurerm_network_interface.example.id]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  custom_data = base64encode(data.template_file.cloud_init.rendered)

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  tags = {
    environment = "testing"
  }
}

resource "null_resource" "install_software" {
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y docker.io",
      "sudo systemctl enable docker",
      "sudo systemctl start docker",
      "sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -",
      "sudo add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\"",
      "sudo apt-get update",
      "sudo apt-get install -y kubelet kubeadm kubectl",
      "sudo snap install minikube --classic",
    ]

    connection {
      type        = "ssh"
      user        = azurerm_linux_virtual_machine.example.admin_username
      host        = azurerm_public_ip.example.ip_address
      private_key = file("~/.ssh/id_rsa")
    }
  }

  depends_on = [azurerm_linux_virtual_machine.example]
}

resource "null_resource" "check_versions" {
  provisioner "remote-exec" {
    inline = [
      "docker --version",
      "kubectl version --client",
      "minikube version",
    ]

    connection {
      type        = "ssh"
      user        = azurerm_linux_virtual_machine.example.admin_username
      host        = azurerm_public_ip.example.ip_address
      private_key = file("~/.ssh/id_rsa")
    }
  }

  depends_on = [null_resource.install_software]
}
