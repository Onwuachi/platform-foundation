---
title: "KB-WEB-001: CloudFront + S3 + Hugo — Directory Path 403 Errors"
date: 2026-06-23
description: "Root cause and fix for a CloudFront + private S3 + Hugo setup where the homepage works but every sub-path (/projects/, /resume/, etc) returns 403 instead of the expected page."
tags: ["cloudfront", "s3", "hugo", "terraform", "aws", "troubleshooting"]
categories: ["kb"]
summary: "Homepage worked, every sub-path returned 403. Root cause: default_root_object only covers the bucket root — fixed with a CloudFront Function that rewrites directory paths to index.html."
---
