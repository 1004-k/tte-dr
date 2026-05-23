# GCP run guide (Paper X)

This guide runs Paper X on a fresh Ubuntu VM using tmux so the job continues if SSH disconnects.

## 1) Create a VM

Suggested starting point:
- Ubuntu 22.04 LTS
- 8 vCPU, 32 GB RAM
- 100 GB disk

## 2) SSH into the VM

From Cloud Shell:

```bash
gcloud compute ssh <VM_NAME> --zone <ZONE>
```

## 3) System dependencies

```bash
sudo apt-get update
sudo apt-get install -y git tmux unzip build-essential \
  libcurl4-openssl-dev libssl-dev libxml2-dev \
  libcairo2-dev libxt-dev \
  libfontconfig1-dev libfreetype6-dev libpng-dev libtiff5-dev libjpeg-dev
```

## 4) Install R

```bash
sudo apt-get install -y r-base r-base-dev
R --version
```

If you prefer the CRAN Ubuntu repo for a newer R, use the CRAN instructions in your local notes.

## 5) Upload and unzip the repository

From Cloud Shell:

```bash
gcloud compute scp ttdr_program_repo.zip <VM_NAME>:~/ --zone <ZONE>
```

On the VM:

```bash
cd ~
unzip -q ttdr_program_repo.zip
cd ttdr_program_repo/paperX_ttedr
```

## 6) Install R packages

```bash
Rscript scripts/00_install_deps.R
```

## 7) Smoke test

```bash
bash scripts/98_quickcheck.sh > quickcheck.log 2>&1
tail -n 80 quickcheck.log
ls -lh quickcheck_paperx/figures
ls -lh quickcheck_paperx/report
```

## 8) Full run with tmux

```bash
chmod +x scripts/99_run_paperx_tmux_gcp.sh
bash scripts/99_run_paperx_tmux_gcp.sh

# monitor
 tmux ls
 tail -f output_paperx_main/run.log
```

To adjust compute knobs:

```bash
N_CORES_MAIN=8 B_MAIN=200 N_MAIN=2000 bash scripts/99_run_paperx_tmux_gcp.sh
```

## 9) Download results

From Cloud Shell:

```bash
gcloud compute scp --recurse \
  <VM_NAME>:~/ttdr_program_repo/paperX_ttedr/output_paperx_main \
  ./output_paperx_main --zone <ZONE>
```

