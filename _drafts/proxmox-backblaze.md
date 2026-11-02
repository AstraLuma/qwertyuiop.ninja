---
layout: post-text
title: Proxmox Backed Up to Backblaze
tags: proxmox, backblaze
# excerpt_separator: <!--more-->
---

Seems simple, right? Doing it well is non-obvious. Here's what I did.

## Background

[Proxmox VE](https://www.proxmox.com/en/products/proxmox-virtual-environment/overview) is a popular "hypervisor" system: It provides tools and UI to manage virtual manchines, containers, their storage, networking, and other operational aspects. It's very popular in the home lab space.

[Backblaze](https://www.backblaze.com/) is a long-respected backup storage provider, providing both PC backup software & storage and the S3-compatible B2 product.

For small-scale production loads, using these together is the obvious option. But how to do so is non-obvious.

### Enter PBS

[Proxmox Backup Server](https://www.proxmox.com/en/products/proxmox-backup-server/overview) is the critical glue. It handles compression & deduplication, replication, and importantly, can store data on disk, in removable storage, or in S3.

### Why Not?

There's two major reasons not to use this:

First, running PBS on Proxmox like below can loosen security, defeating the advertised ransomware protection: root on the hypervisor can access the S3 credentials, which include modifying and deleting backup data. If this is a concern for you, run PBS on a separate server and make sure to harden it.

Second, PBS's data is kept in a proprietary format. You almost certainly cannot read it without running a copy of the PBS server. This is in contrast with Proxmox's local file backups, which are just snapshots of the backing store and readily readable by third-party tools. If this bothers you, I suggest using Proxmox's file backup and running some kind of secondary synchronization process.

## Process

What follows is how I set up Proxmox and PBS, based on loose notes I kept.

In particular, most of this can be done through the Web UI. I didn't because at the time, I didn't realize it would be accessible while Proxmox was running.


### 0. Proxmox

I'm assuming you already have Proxmox VE, making use of ZFS. (btrfs will also probably be ok.) It might be helpful to have at least dummy workloads so you have something to back up.

If you're not using ZFS or btrfs or another CoW system, backups will just be less efficient. Snapshotting filesystems are so good.


### 1. PBS Installation

([PBS Docs](https://pbs.proxmox.com/docs/installation.html#install-proxmox-backup-server-on-proxmox-ve))

Append the following to `/etc/apt/sources.list.d/pbs-enterprise.sources`:

```
Types: deb
URIs: https://enterprise.proxmox.com/debian/pbs
Suites: trixie
Components: pbs-enterprise
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
```

And run:

```
apt install proxmox-backup-server
```


### 2. Create Bucket & Endpoint

In the Backblaze UI, create a bucket and app key. The key should have read/write access to bucket files but should not be able to manage buckets. Write down the bucket name, the region, the key ID, and secret. Also change the lifecycle settings: I recommend "Keep only the last version of the file", since PBS will be handling a lot of this.

Back on proxmox, run the command to create the endpoint:

```
proxmox-backup-manager s3 endpoint create backblaze --access-key <KEY> --secret-key '<SECRET>' --endpoint '{{bucket}}.s3.{{region}}.backblazeb2.com' --region '<REGION>' --provider-quirks skip-if-none-match-header
```

Note that you _should_ substitute `<KEY>`, `<SECRET>`, and `<REGION>`, but should _not_ substitute `{{bucket}}` and `{{region}}`.

And then run these to crete the datastore:

```
zfs create -o mountpoint=/var/lib/proxmox-backup-server rpool/proxmox-backup-server
proxmox-backup-manager datastore create <STORENAME> /var/lib/proxmox-backup-server/<STORENAME> --backend type=s3,client=backblaze,bucket=<BUCKET> --gc-schedule daily
```

This will create a ZFS subvolume for the local cache of backup data, and then create the actual PBS datastore.

#### Cache??

The way PBS S3 support works (to my understanding) is that a cache of the S3 data is kept locally, to reduce network operations, but disk space restrictions are respected. This is why we created a zvol above: you can set disk space limitations on PBS's local data, and PBS will recognize and respect it.

I set mine to 1% of the available disk space for now. We'll see if that needs to change as my dataset grows. My gut says that for efficient performance, it should be at least the size of one copy of the dataset, but if PBS has good chunking and is doing CAS things, this is not necessarily true.

### 3. Credentials

On the server:

```
proxmox-backup-manager user generate-token root@pam pve
proxmox-backup-manager acl update / DatastoreReader --auth-id 'root@pam!pve'
proxmox-backup-manager acl update /datastore DatastorePowerUser --auth-id 'root@pam!pve'
```

Write down the token generated in the first command

### 4. Configure PVE

At this point, Proxmox Backup Server should now be ready, and we can configure Proxmox Virtual Environment.

First, run:

```
proxmox-backup-manager cert info
```

And write down the fingerpint. It should be colon-separated hex.

In the Proxmox VE UI, under the Datacenter object, in the Storage screen, click Add > Proxmox Backup Server. The server will be `127.0.0.1`, the username will be `root@pam!pve`, the password will be the above token, and the fingerprint is the certificate fingerprint.

Finally, create a backup job. This is largely to taste, but I like setting few jobs with broad wildcards. (Currently, I have one backup job that does all guests except some templates.) Trigger it manually right now so you know everything above is correct.

## Tidying Up

At this point, your data is backed up. You can stop now. But there's a few odds and ends I feel like I should mention.

### Garbage Collection

As old backups are cleaned up, orphan data will be left in the PBS store. Garbage Collection (GC) jobs clean this up. The above instructions will do a GC pass daily, but you may wish to customize this.

### Retention

Cleaning up old backups is pretty important. Proxmox provides several places to do this:

* PBS global prune jobs
* PBS datastore prune jobs
* PVE storage settings
* PVE backup job

I'm currently using the last, but any (or multiple) of these will work.

### Verification

PBS has an option for verification, where it confirms that the backup was actually written and is correct.

I have this turned off, because under S3 it forcibly downloads the entirety of each snapshot, without regard to caching or duplicate work, which is wildly inefficient and raised concerns about server bandwidth. And I'm paying Backblaze money to make sure that may data is correct.

I assume if you have a stand-alone PBS server and are using local disks, you'll want this on.

### Bandwidth Limits

Because I'm setting this up on a server in colo, and it's connecting to a cloud service built for efficient data transfer, PBS will happily use quite a bit of bandwidth. I recommend configuring policies in Traffic Control to limit this to something that's sensible for you.


## Results

I haven't had to restore yet, but on a 21GB dataset and keeping 6 backups, the file snapshot store is using >80GB and PBS is reporting <20GB locally.
