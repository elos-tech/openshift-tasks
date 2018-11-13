
# Setup Nexus Repository
oc new-project csas-nexus --display-name "Nexus Repository Server"

oc new-app sonatype/nexus3:latest

oc expose svc nexus3

oc rollout pause dc nexus3

oc patch dc nexus3 --patch='{ "spec": { "strategy": { "type": "Recreate" }}}'

oc set resources dc nexus3 --limits=memory=1Gi,cpu=1 --requests=memory=500Mi,cpu=500m

echo "apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nexus-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 4Gi" | oc create -f -

oc set volume dc/nexus3 --add --overwrite --name=nexus3-volume-1 --mount-path=/nexus-data/ --type persistentVolumeClaim --claim-name=nexus-pvc

oc set probe dc/nexus3 --liveness --failure-threshold 3 --initial-delay-seconds 60 -- echo ok
oc set probe dc/nexus3 --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:8081/repository/maven-public/

oc rollout resume dc nexus3

# Setup Repository Structure
# cd /tmp
# curl -o setup_nexus3.sh -s https://raw.githubusercontent.com/wkulhanek/ocp_advanced_development_resources/master/nexus/setup_nexus3.sh
# chmod +x setup_nexus3.sh
# ./setup_nexus3.sh admin admin123 http://localhost:8081

# Setup Sonarqube Server
oc new-project csas-sonarqube --display-name "Sonarqube Analysis Server"

oc new-app --template=postgresql-persistent --param POSTGRESQL_USER=sonar --param POSTGRESQL_PASSWORD=sonar --param POSTGRESQL_DATABASE=sonar --param VOLUME_CAPACITY=4Gi --labels=app=sonarqube_db

oc new-app --docker-image=wkulhanek/sonarqube:6.7.4 --env=SONARQUBE_JDBC_USERNAME=sonar --env=SONARQUBE_JDBC_PASSWORD=sonar --env=SONARQUBE_JDBC_URL=jdbc:postgresql://postgresql/sonar --labels=app=sonarqube

oc rollout pause dc sonarqube
oc expose service sonarqube

echo "apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: sonarqube-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 4Gi" | oc create -f -
oc set volume dc/sonarqube --add --overwrite --name=sonarqube-volume-1 --mount-path=/opt/sonarqube/data/ --type persistentVolumeClaim --claim-name=sonarqube-pvc

oc set resources dc/sonarqube --limits=memory=1Gi,cpu=1 --requests=memory=1Gi,cpu=500m
oc patch dc sonarqube --patch='{ "spec": { "strategy": { "type": "Recreate" }}}'

oc set probe dc/sonarqube --liveness --failure-threshold 3 --initial-delay-seconds 40 -- echo ok
oc set probe dc/sonarqube --readiness --failure-threshold 3 --initial-delay-seconds 20 --get-url=http://:9000/about

oc rollout resume dc sonarqube

# Setup Jenkins Master Server
oc new-project csas-jenkins --display-name "Jenkins Master Server"

oc new-app jenkins-persistent --param ENABLE_OAUTH=true --param MEMORY_LIMIT=2Gi --param VOLUME_CAPACITY=4Gi

#
# Set up Dev Project
oc new-project csas-tasks-dev --display-name "Tasks Application Development"
oc policy add-role-to-user edit system:serviceaccount:csas-jenkins:jenkins -n csas-tasks-dev

# Set up Dev Application


oc new-build --binary=true --name="tasks" --docker-image=jboss/wildfly:latest -n csas-tasks-dev

# Edit buildconfig
source:
    binary: {}
    dockerfile: |-
      FROM jboss/wildfly
      ADD tasks-*.war /opt/jboss/wildfly/standalone/deployments/
    type: Binary



oc new-app csas-tasks-dev/tasks:0.0-0 --name=tasks --allow-missing-imagestream-tags=true --allow-missing-images -n csas-tasks-dev

oc set triggers dc/tasks --remove-all -n csas-tasks-dev
oc expose dc tasks --port 8080 -n csas-tasks-dev
oc expose svc tasks -n csas-tasks-dev

oc create configmap tasks-config --from-literal="application-users.properties=Placeholder" --from-literal="application-roles.properties=Placeholder" -n csas-tasks-dev

oc set volume dc/tasks --add --name=jboss-config --mount-path=/opt/jboss/wildfly/standalone/configuration/application-users.properties --sub-path=application-users.properties --configmap-name=tasks-config -n csas-tasks-dev

oc set volume dc/tasks --add --name=jboss-config1 --mount-path=/opt/jboss/wildfly/standalone/configuration/application-roles.properties --sub-path=application-roles.properties --configmap-name=tasks-config -n csas-tasks-dev


