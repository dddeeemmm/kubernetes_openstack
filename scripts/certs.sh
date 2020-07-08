#---
wget -q --show-progress --https-only --timestamping \
https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 \
https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64

chmod +x cfssl_linux-amd64 cfssljson_linux-amd64
sudo mv cfssl_linux-amd64 /usr/local/bin/cfssl
sudo mv cfssljson_linux-amd64 /usr/local/bin/cfssljson


mkdir root-ca
cd root-ca
cat << EOF > root-ca-config.json
{
    "signing": {
        "profiles": {
            "intermediate": {
                "usages": [
                    "signature",
                    "digital-signature",
                    "cert sign",
                    "crl sign"
                ],
                "expiry": "87600h",
                "ca_constraint": {
                    "is_ca": true,
                    "max_path_len": 0,
                    "max_path_len_zero": true
                }
            }
        }
    }
}
EOF
cat << EOF > root-ca-csr.json
{
    "CN": "my-root-ca",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "ca": {
        "expiry": "87600h"
    }
}
EOF
cfssl genkey -initca root-ca-csr.json | cfssljson -bare ca
cd ..

mkdir kubernetes-ca
cd kubernetes-ca
cat << EOF > kubernetes-ca-csr.json
{
    "CN": "kubernetes-ca",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "ca": {
        "expiry": "87600h"
    }
}
EOF
cfssl genkey -initca kubernetes-ca-csr.json | cfssljson -bare kubernetes-ca
cfssl sign -ca ../root-ca/ca.pem -ca-key ../root-ca/ca-key.pem -config ../root-ca/root-ca-config.json -profile intermediate kubernetes-ca.csr | cfssljson -bare kubernetes-ca
cfssl print-defaults config > kubernetes-ca-config.json
cd ..


mkdir kubernetes-front-proxy-ca
cd kubernetes-front-proxy-ca
cat << EOF > kubernetes-front-proxy-ca-csr.json
{
    "CN": "kubernetes-front-proxy-ca",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "ca": {
        "expiry": "87600h"
    }
}
EOF
cfssl genkey -initca kubernetes-front-proxy-ca-csr.json | cfssljson -bare kubernetes-front-proxy-ca
cfssl sign -ca ../root-ca/ca.pem -ca-key ../root-ca/ca-key.pem -config ../root-ca/root-ca-config.json -profile intermediate kubernetes-front-proxy-ca.csr | cfssljson -bare kubernetes-front-proxy-ca
cfssl print-defaults config > kubernetes-front-proxy-ca-config.json
cd ..

mkdir etcd-ca
cd etcd-ca
cat << EOF > etcd-ca-config.json
{
  "signing": {
    "default": {
        "usages": [
          "signing",
          "key encipherment",
          "server auth",
          "client auth"
        ],
        "expiry": "87600h"
    }
  }
}
EOF
cat << EOF > etcd-ca-csr.json
{
    "CN": "etcd-ca",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "ca": {
        "expiry": "87600h"
    }

}
EOF
cfssl genkey -initca etcd-ca-csr.json | cfssljson -bare etcd-ca
cfssl sign -ca ../root-ca/ca.pem -ca-key ../root-ca/ca-key.pem -config ../root-ca/root-ca-config.json -profile intermediate etcd-ca.csr | cfssljson -bare etcd-ca
cd ..
cat << EOF > etcd-server-csr.json
{
  "CN": "kube-etcd",
  "hosts": [
    "localhost",
    "k8s-1",
    "k8s-2",
    "k8s-3",
    "k8s-1.local",
    "k8s-2.local",
    "k8s-3.local",
    "10.112.29.18",
    "10.112.29.23",
    "10.112.29.42"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
EOF
cfssl gencert -ca=etcd-ca/etcd-ca.pem -ca-key=etcd-ca/etcd-ca-key.pem --config=etcd-ca/etcd-ca-config.json -profile=server etcd-server-csr.json | cfssljson -bare etcd-server

cat << EOF > etcd-peer-csr.json
{
  "CN": "etcd",
  "hosts": [
    "localhost",
    "k8s-1",
    "k8s-2",
    "k8s-3",
    "k8s-1.local",
    "k8s-2.local",
    "k8s-3.local",
    "10.112.29.18",
    "10.112.29.23",
    "10.112.29.42"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}

EOF
cfssl gencert -ca=etcd-ca/etcd-ca.pem -ca-key=etcd-ca/etcd-ca-key.pem --config=etcd-ca/etcd-ca-config.json -profile=peer etcd-peer-csr.json | cfssljson -bare etcd-peer
cat << EOF > etcd-healthcheck-client-csr.json
{
  "CN": "kube-etcd-healthcheck-client",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
      {
          "O": "system:masters"
      }
  ]
}
EOF
cfssl gencert -ca=etcd-ca/etcd-ca.pem -ca-key=etcd-ca/etcd-ca-key.pem --config=etcd-ca/etcd-ca-config.json -profile=client etcd-healthcheck-client-csr.json | cfssljson -bare etcd-healthcheck-client
cat << EOF > apiserver-csr.json
{
  "CN": "kube-apiserver",
  "hosts": [
    "localhost",
    "k8s-1",
    "k8s-2",
    "k8s-3",
    "k8s-1.local",
    "k8s-2.local",
    "k8s-3.local",
    "10.112.29.18",
    "10.112.29.23",
    "10.112.29.42",
    "kubernetes",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.cluster",
    "kubernetes.default.svc.cluster.local"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
EOF
cfssl gencert -ca=kubernetes-ca/kubernetes-ca.pem -ca-key=kubernetes-ca/kubernetes-ca-key.pem --config=kubernetes-ca/kubernetes-ca-config.json -profile=www apiserver-csr.json | cfssljson -bare apiserver

cat << EOF > apiserver-kubelet-client-csr.json
{
  "CN": "kube-apiserver-kubelet-client",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "O": "system:masters"
    }
  ]
}
EOF
cfssl gencert -ca=kubernetes-ca/kubernetes-ca.pem -ca-key=kubernetes-ca/kubernetes-ca-key.pem --config=kubernetes-ca/kubernetes-ca-config.json -profile=client apiserver-kubelet-client-csr.json | cfssljson -bare apiserver-kubelet-client

 
openssl genrsa -out sa.key 2048
openssl rsa -in sa.key -pubout -out sa.pub
 
cat << EOF > front-proxy-client-csr.json
{
  "CN": "front-proxy-client",
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
EOF
cfssl gencert -ca=kubernetes-front-proxy-ca/kubernetes-front-proxy-ca.pem -ca-key=kubernetes-front-proxy-ca/kubernetes-front-proxy-ca-key.pem --config=kubernetes-front-proxy-ca/kubernetes-front-proxy-ca-config.json -profile=client front-proxy-client-csr.json | cfssljson -bare front-proxy-client
 
cat << EOF > apiserver-etcd-client-csr.json
{
  "CN": "kube-apiserver-etcd-client",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
      {
          "O": "system:masters"
      }
  ]
}
EOF
cfssl gencert -ca=etcd-ca/etcd-ca.pem -ca-key=etcd-ca/etcd-ca-key.pem --config=etcd-ca/etcd-ca-config.json -profile=client apiserver-etcd-client-csr.json | cfssljson -bare apiserver-etcd-client
 
cat << EOF > admin-csr.json
{
  "CN": "kubernetes-admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "O": "system:masters"
    }
  ]
}
EOF
cfssl gencert -ca=kubernetes-ca/kubernetes-ca.pem -ca-key=kubernetes-ca/kubernetes-ca-key.pem --config=kubernetes-ca/kubernetes-ca-config.json -profile=client admin-csr.json | cfssljson -bare admin
KUBECONFIG=admin.conf kubectl config set-cluster default-cluster --server=https://10.112.29.18:6443 --certificate-authority kubernetes-ca/kubernetes-ca.pem --embed-certs
KUBECONFIG=admin.conf kubectl config set-credentials default-admin --client-key admin-key.pem --client-certificate admin.pem --embed-certs
KUBECONFIG=admin.conf kubectl config set-credentials default-admin --client-key admin-key.pem --client-certificate admin.pem --embed-certs
KUBECONFIG=admin.conf kubectl config set-context default-system --cluster default-cluster --user default-admin
KUBECONFIG=admin.conf kubectl config use-context default-system

cat << EOF > kubelet-csr.json
{
  "CN": "system:node:ubuntu",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "O": "system:nodes"
    }
  ]
}
EOF
cfssl gencert -ca=kubernetes-ca/kubernetes-ca.pem -ca-key=kubernetes-ca/kubernetes-ca-key.pem --config=kubernetes-ca/kubernetes-ca-config.json -profile=client kubelet-csr.json | cfssljson -bare kubelet
KUBECONFIG=kubelet.conf kubectl config set-cluster default-cluster --server=https://10.112.29.18:6443 --certificate-authority kubernetes-ca/kubernetes-ca.pem --embed-certs
KUBECONFIG=kubelet.conf kubectl config set-credentials system:node:ubuntu --client-key kubelet-key.pem --client-certificate kubelet.pem --embed-certs
KUBECONFIG=kubelet.conf kubectl config set-context default-system --cluster default-cluster --user system:node:ubuntu
KUBECONFIG=kubelet.conf kubectl config use-context default-system

cat << EOF > controller-manager-csr.json
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
EOF
cfssl gencert -ca=kubernetes-ca/kubernetes-ca.pem -ca-key=kubernetes-ca/kubernetes-ca-key.pem --config=kubernetes-ca/kubernetes-ca-config.json -profile=client controller-manager-csr.json | cfssljson -bare controller-manager
KUBECONFIG=controller-manager.conf kubectl config set-cluster default-cluster --server=https://10.112.29.18:6443 --certificate-authority kubernetes-ca/kubernetes-ca.pem --embed-certs
KUBECONFIG=controller-manager.conf kubectl config set-credentials default-controller-manager --client-key controller-manager-key.pem --client-certificate controller-manager.pem --embed-certs
KUBECONFIG=controller-manager.conf kubectl config set-context default-system --cluster default-cluster --user default-controller-manager
KUBECONFIG=controller-manager.conf kubectl config use-context default-system

cat << EOF > scheduler-csr.json
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
EOF
cfssl gencert -ca=kubernetes-ca/kubernetes-ca.pem -ca-key=kubernetes-ca/kubernetes-ca-key.pem --config=kubernetes-ca/kubernetes-ca-config.json -profile=client scheduler-csr.json | cfssljson -bare scheduler
KUBECONFIG=scheduler.conf kubectl config set-cluster default-cluster --server=https://10.112.29.18:6443 --certificate-authority kubernetes-ca/kubernetes-ca.pem --embed-certs
KUBECONFIG=scheduler.conf kubectl config set-credentials default-scheduler --client-key scheduler-key.pem --client-certificate scheduler.pem --embed-certs
KUBECONFIG=scheduler.conf kubectl config set-context default-system --cluster default-cluster --user default-scheduler
KUBECONFIG=scheduler.conf kubectl config use-context default-system


mkdir -p /etc/kubernetes/pki/etcd/
cp  etcd-ca/etcd-ca.pem /etc/kubernetes/pki/etcd/ca.crt
cp  etcd-ca/etcd-ca-key.pem /etc/kubernetes/pki/etcd/ca.key
cp  kubernetes-ca/kubernetes-ca.pem /etc/kubernetes/pki/ca.crt
cp  kubernetes-ca/kubernetes-ca-key.pem /etc/kubernetes/pki/ca.key
cp  kubernetes-front-proxy-ca/kubernetes-front-proxy-ca.pem /etc/kubernetes/pki/front-proxy-ca.crt
cp  kubernetes-front-proxy-ca/kubernetes-front-proxy-ca-key.pem /etc/kubernetes/pki/front-proxy-ca.key
cp  kubernetes-front-proxy-ca/kubernetes-front-proxy-ca.pem  /etc/kubernetes/pki/front-proxy-ca.crt
cp  kubernetes-ca/kubernetes-ca.pem /etc/kubernetes/pki/ca.crt
cp  kubernetes-ca/kubernetes-ca.pem /etc/kubernetes/pki/ca.crt
cp  etcd-ca/etcd-ca.pem /etc/kubernetes/pki/etcd/ca.crt
cp  etcd-server.pem /etc/kubernetes/pki/etcd/server.crt
cp  etcd-server-key.pem /etc/kubernetes/pki/etcd/server.key
cp  etcd-peer.pem /etc/kubernetes/pki/etcd/peer.crt
cp  etcd-peer-key.pem /etc/kubernetes/pki/etcd/peer.key
cp  etcd-healthcheck-client.pem /etc/kubernetes/pki/etcd/healthcheck-client.crt
cp  etcd-healthcheck-client-key.pem /etc/kubernetes/pki/etcd/healthcheck-client.key
cp  apiserver.pem /etc/kubernetes/pki/apiserver.crt
cp  apiserver-key.pem /etc/kubernetes/pki/apiserver.key
cp  apiserver-kubelet-client.pem /etc/kubernetes/pki/apiserver-kubelet-client.crt
cp  apiserver-kubelet-client-key.pem /etc/kubernetes/pki/apiserver-kubelet-client.key
cp  apiserver-etcd-client.pem /etc/kubernetes/pki/apiserver-etcd-client.crt
cp  apiserver-etcd-client-key.pem /etc/kubernetes/pki/apiserver-etcd-client.key
cp  front-proxy-client.pem /etc/kubernetes/pki/front-proxy-client.crt 
cp  front-proxy-client-key.pem /etc/kubernetes/pki/front-proxy-client.key
cp  sa.pub /etc/kubernetes/pki/sa.pub
cp  sa.key /etc/kubernetes/pki/sa.key
cp  admin.conf /etc/kubernetes/admin.conf
cp  kubelet.conf /etc/kubernetes/kubelet.conf
cp  controller-manager.conf /etc/kubernetes/controller-manager.conf
cp  scheduler.conf /etc/kubernetes/scheduler.conf

