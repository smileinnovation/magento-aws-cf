default: base-image

base-image: magento-elasticsearch magento-node

magento-elasticsearch:
	@docker build -t magento-elasticsearch ./docker/magento-elasticsearch

magento-elasticsearch-aws:
	@docker build -t magento-elasticsearch-aws ./docker/magento-elasticsearch-aws
	@docker tag magento-elasticsearch-aws 274275471339.dkr.ecr.us-east-1.amazonaws.com/smile-innovation/showroom/magento-elasticsearch-aws

magento-node:
	@docker build -t magento-node ./docker/magento-node

smileshop:
	@docker build -t smileshop ./docker/smileshop
	@docker tag smileshop 274275471339.dkr.ecr.us-east-1.amazonaws.com/smile-innovation/showroom/smileshop-magento
