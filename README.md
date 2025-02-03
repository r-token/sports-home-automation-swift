# Sports Home Automation with Swift Cloud

Backend serverless IaC on AWS written in Swift and deployed via [Swift Cloud](https://github.com/swift-cloud/swift-cloud).

It currently consists of four pieces of infrastructure, all defined within `Infra/Project.swift`:
1. A cron job managed by EventBridge Schedules
2. A poller Lambda function that polls the [ncaa-api](https://github.com/henrygd/ncaa-api) for Tulsa football, men's basketball, and women's basketball results. It writes those results to DynamoDB
3. A DynamoDB table that keeps track of the Tulsa games found in the previous step
4. A processor Lambda function triggered by DynamoDB Streams that checks if the game is over and Tulsa won. If both are true, make my Phillips Hue lights go nuts
