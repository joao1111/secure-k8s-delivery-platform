ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
TOOLS := $(ROOT)/.tools
export PATH := $(TOOLS):$(TOOLS)/venv/bin:$(PATH)
PY := $(TOOLS)/venv/bin/python

.PHONY: tools prove prove-live kind-up kind-down

tools:
	bash scripts/install_tools.sh

prove: tools
	kyverno test tests/kyverno --require-tests
	$(PY) -m unittest discover -s tests/scripts -v
	$(PY) scripts/check_exceptions.py policies/exceptions
	@if $(PY) scripts/check_exceptions.py tests/exceptions/expired; then echo "expired exception was accepted"; exit 1; fi
	$(PY) scripts/check_suppressions.py suppressions
	@if $(PY) scripts/check_suppressions.py tests/suppressions/expired; then echo "expired suppression was accepted"; exit 1; fi
	$(PY) scripts/check_action_pins.py .github/workflows
	@if $(PY) scripts/check_action_pins.py tests/actions/unpinned; then echo "unpinned action was accepted"; exit 1; fi
	$(PY) scripts/check_action_pins.py tests/actions/pinned
	$(PY) scripts/run_scanners.py
	$(PY) scripts/check_catalog.py

kind-up: tools
	@if ! kind get clusters | grep -qx secure-delivery; then \
	  kind create cluster --name secure-delivery --config cluster/kind-config.yaml; \
	fi
	kubectl apply --server-side -f https://raw.githubusercontent.com/projectcalico/calico/v3.33.1/manifests/calico.yaml
	kubectl -n kube-system set env daemonset/calico-node FELIX_IGNORELOOSERPF=true
	kubectl -n kube-system rollout status daemonset/calico-node --timeout=240s
	kubectl wait --for=condition=Ready nodes --all --timeout=240s
	helm repo add kyverno https://kyverno.github.io/kyverno/
	helm repo update kyverno
	helm upgrade --install kyverno kyverno/kyverno \
	  --version 3.10.0 \
	  --namespace kyverno --create-namespace \
	  --set admissionController.replicas=1 \
	  --set backgroundController.replicas=1 \
	  --set cleanupController.replicas=1 \
	  --set reportsController.replicas=1 \
	  --set features.policyExceptions.enabled=true \
	  --set-string features.policyExceptions.namespace='*' \
	  --wait --timeout 10m

kind-down:
	kind delete cluster --name secure-delivery

prove-live: tools
	bash scripts/prove_live.sh
