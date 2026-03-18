---
layout: post-text
title: Container Platforms
tags: 
excerpt_separator: <!--more-->
---

Nobody actually defines what the container platform strings are, and how they overlap. I went splunking so you don't have to.

<!--more-->

## Background

Part of the container specification is the idea of "platforms"--operating system and CPU architecture in a neat little package. They show up in a bunch of places if you go looking: `docker run` has a `--platform`, you can say `FROM --platform` in your Dockerfile (in buildx), the docker github actions often have `platforms` inputs/outputs, etc.

It's also very common to install qemu to allow transparent (if not slow) cross-platform container builder, either through a system package (as I've [discussed]({% post_url 2020-05-18-gamebear-25 %}) [before]({% post_url 2026-03-16-codeberg-runner %})), or as a CI/CD step (eg [`docker/setup-qemu-action`](github.com/docker/setup-qemu-action))

However, none of the documentation actually tells you what these strings are, so you're left wondering what `linux/amd64/v3` is and should you build it separately.


## The Story

So if you check the buildx CLI argument documentation, specifically [`docker buildx build --platform`](https://github.com/docker/buildx/blob/v0.32/docs/reference/buildx_build.md#platform), it'll tell you that it's defined in the containerd source code.

And if you go check the [containerd source code](https://github.com/containerd/containerd/blob/v1.4.3/platforms/platforms.go#L63), you'll see it says some things about slashes but that the values ultimately come from GOARCH and GOOS.

And then if you go searching, you might [the go build instructions](https://go.dev/doc/install/source#environment) which include the list of valid values Architecture, OS, & Variant, as well as the valid combinations.

The basic format is `<OS>/<ARCH>` or `<OS>/<ARCH>/<VARIANT>`, but many inputs will accept just `<OS>` or `<ARCH>`.


## The Table

The main part of the platform is `os/arch`, which describe the OS and CPU the container is valid for. I've made a lovely table of which ones are available and where they're valid.

| OS          | `386` | `amd64` | `arm` | `arm64` | `loong64` | `mips` | `mips64` | `mips64le` | `mipsle` | `ppc64` | `ppc64le` | `riscv64` | `s390x` | `wasm`  
| ----------- | ----- | ------- | ----- | ------- | --------- | ------ | -------- | ---------- | -------- | ------- | --------- | --------- | ------- | ------
| `aix`       |       |         |       |         |           |        |          |            |          | ✅      |           |           |         |
| `android`   | ✅    | ✅      | ✅    | ✅      |           |        |          |            |          |         |           |           |         |
| `darwin`    |       | ✅      |       | ✅      |           |        |          |            |          |         |           |           |         |
| `dragonfly` |       | ✅      |       |         |           |        |          |            |          |         |           |           |         |
| `freebsd`   | ✅    | ✅      | ✅    |         |           |        |          |            |          |         |           |           |         |
| `illumos`   | ✅    |         |       |         |           |        |          |            |          |         |           |           |         |
| `ios`       |       |         |       | ✅      |           |        |          |            |          |         |           |           |         |
| `js`        |       |         |       |         |           |        |          |            |          |         |           |           |         | ✅
| `linux`     | ✅    | ✅      | ✅    | ✅      | ✅       | ✅     | ✅       | ✅         | ✅       | ✅      | ✅        | ✅       | ✅      |
| `netbsd`    | ✅    | ✅      | ✅    |         |           |        |          |            |          |         |           |           |         |
| `openbsd`   | ✅    | ✅      | ✅    | ✅      |           |        |          |            |          |         |           |           |         |
| `plan9`     | ✅    | ✅      | ✅    |         |           |        |          |            |          |         |           |           |         |
| `solaris`   |       | ✅      |       |         |           |        |          |            |          |         |           |           |         |
| `wasip1`    |       |         |       |         |           |        |          |            |          |         |           |           |         | ✅
| `windows`   | ✅    | ✅      | ✅    | ✅      |           |        |          |            |          |         |           |           |         |


(Sorry about the table, mobile users. Hopefully I'll improve it later.)

Additionally, containerd documents these aliases:

| Alias     | Real
| --------- | ----
| `aarch64` | `arm64`
| `armhf`   | `arm/v7`
| `armel`   | `arm/v6`
| `i386`    | `386`
| `x86_64`  | `amd64`
| `x86-64`  | `amd64`
| `macos`   | `darwin`


## Variants

_Additionally_, a number of architectures define variants--usually instruction set enhancements, but sometimes things like floating point handling. These are mostly copied directly from the go docs. There's often backwards compatibility, but not universally.

Also, the default when building varies. Sometimes it's autodetected, sometimes it's minimum.

If anyone has references to how containers handle backwards compatibility or default variants, let me know.


### `386`

* `softfloat`: use software floating point operations; should support all x86 chips (Pentium MMX or later).
* `sse2`: use SSE2 for floating point operations; has better performance but only available on Pentium 4/Opteron/Athlon 64 or later.


### `arm`

* `v5`: use software floating point; when CPU doesn't have VFP co-processor
* `v6`: use VFPv1 only; default if cross compiling; usually ARM11 or better cores (VFPv2 or better is also supported)
* `v7`: use VFPv3; usually Cortex-A cores


### `amd64`

* `v1`: The baseline. Exclusively generates instructions that all 64-bit x86 processors can execute
* `v2`: all v1 instructions, plus CMPXCHG16B, LAHF, SAHF, POPCNT, SSE3, SSE4.1, SSE4.2, SSSE3
* `v3`: all v2 instructions, plus AVX, AVX2, BMI1, BMI2, F16C, FMA, LZCNT, MOVBE, OSXSAVE
* `v4`: all v3 instructions, plus AVX512F, AVX512BW, AVX512CD, AVX512DQ, AVX512VL


### `mips`, `mips64`, `mipsle`, `mips64le`

* `hardfloat`: use floating point instructions
* `softfloat`: use soft floating point


### `ppc64`, `ppc64le`

* `power8`: ISA v2.07
* `power9`: ISA v3.00


### `riscv64`

* `rva20u64`: only use RISC-V extensions that are mandatory in the RVA20U64 profile
* `rva22u64`: only use RISC-V extensions that are mandatory in the RVA22U64 profile
* `rva23u64`: only use RISC-V extensions that are mandatory in the RVA23U64 profile


### `wasm`

Unlike all the other architectures, `wasm` variants are a comma separated list of additional experimental features:

* `satconv`: saturating (non-trapping) float-to-int conversions
* `signext`: sign-extension operators
