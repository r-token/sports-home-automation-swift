# Sports Home Automation with Swift Cloud

Backend serverless IaC on AWS written in Swift and deployed via [Swift Cloud](https://github.com/swift-cloud/swift-cloud).

It currently consists of six pieces of infrastructure, all defined within `Infra/Project.swift`:
1. A cron job managed by EventBridge Scheduler that triggers my scheduler function
2. An SQS queue to hold sports-api poller events
3. A scheduler Lambda function that fires off SQS events every 10 seconds
4. A poller Lambda function triggered by SQS that polls the [ncaa-api](https://github.com/henrygd/ncaa-api) for Tulsa football, men's basketball, and women's basketball results. It writes those results to DynamoDB
5. A DynamoDB table that keeps track of the Tulsa games found in the previous step
6. A processor Lambda function triggered by DynamoDB Streams that checks if the game is over and Tulsa won. If both are true, make my Philips Hue lights go nuts
