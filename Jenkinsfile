#!groovy

// Run this pipeline on the custom Maven Slave ('maven-appdev')
// Maven Slaves have JDK and Maven already installed
// 'maven-appdev' has skopeo installed as well.
node('maven') {
  // Define Maven Command. Make sure it points to the correct
  // settings for our Nexus installation (use the service to
  // bypass the router). The file nexus_openshift_settings.xml
  // needs to be in the Source Code repository.
  def mvnCmd = "mvn -s ./nexus_openshift_settings.xml"

  // Checkout Source Code
  stage('Checkout Source') {
    // TBD
    git 'https://github.com/elos-tech/openshift-tasks.git'
  }

  // The following variables need to be defined at the top level
  // and not inside the scope of a stage - otherwise they would not
  // be accessible from other stages.
  // Extract version and other properties from the pom.xml
  def groupId    = getGroupIdFromPom("pom.xml")
  def artifactId = getArtifactIdFromPom("pom.xml")
  def version    = getVersionFromPom("pom.xml")

  // Set the tag for the development image: version + build number
  def devTag  = "${version}-${BUILD_NUMBER}"
  // Set the tag for the production image: version
  def prodTag = "${version}"

  // Using Maven build the war file
  // Do not run tests in this step
  stage('Build war') {
    echo "Building version ${version}"
    
    sh "${mvnCmd} clean package -DskipTests"
  }

  // Using Maven run the unit tests
  stage('Unit Tests') {
    echo "Running Unit Tests"
    
    sh "${mvnCmd} test"
  }

  // Using Maven call SonarQube for Code Analysis
  stage('Code Analysis') {
    echo "Running Code Analysis"
    
    sh "${mvnCmd} sonar:sonar -Dsonar.host.url=http://sonarqube.csas-sonarqube.svc:9000 -Dsonar.projectName=${JOB_BASE_NAME} -Dsonar.projectVersion=${devTag}"
  }

  // Publish the built war file to Nexus
  stage('Publish to Nexus') {
    echo "Publish to Nexus"
    
    sh "${mvnCmd} deploy -DskipTests=true -DaltDeploymentRepository=nexus::default::http://nexus3.csas-nexus.svc:8081/repository/releases"
  }

  // Build the OpenShift Image in OpenShift and tag it.
  stage('Build and Tag OpenShift Image') {
    echo "Building OpenShift container image tasks:${devTag}"


  // Use the file you just published into Nexus:
    sh "oc start-build tasks --follow --from-file=http://nexus3.csas-nexus.svc:8081/repository/releases/org/jboss/quickstarts/eap/tasks/${version}/tasks-${version}.war -n csas-tasks-dev"

  // Tag the image using the devTag
  openshiftTag alias: 'false', destStream: 'tasks', destTag: devTag, destinationNamespace: 'csas-tasks-dev', namespace: 'csas-tasks-dev', srcStream: 'tasks', srcTag: 'latest', verbose: 'false'
  }

  // Deploy the built image to the Development Environment.
  stage('Deploy to Dev') {
    echo "Deploying container image to Development Project"
    // Update the Image on the Development Deployment Config
    sh "oc set image dc/tasks tasks=172.30.1.1:5000/csas-tasks-dev/tasks:${devTag} -n csas-tasks-dev"

    // Update the Config Map which contains the users for the Tasks application
    sh "oc delete configmap tasks-config -n csas-tasks-dev --ignore-not-found=true"
    sh "oc create configmap tasks-config --from-file=./configuration/application-users.properties --from-file=./configuration/application-roles.properties -n csas-tasks-dev"

    // Deploy the development application.
    openshiftDeploy depCfg: 'tasks', namespace: 'csas-tasks-dev', verbose: 'false', waitTime: '', waitUnit: 'sec'
    
    openshiftVerifyDeployment depCfg: 'tasks', namespace: 'csas-tasks-dev', replicaCount: '1', verbose: 'false', verifyReplicaCount: 'false', waitTime: '', waitUnit: 'sec'
    openshiftVerifyService namespace: 'csas-tasks-dev', svcName: 'tasks', verbose: 'false'
  }

  // Run Integration Tests in the Development Environment.
  stage('Integration Tests') {
    echo "Running Integration Tests"
    sleep 30

    // Create a new task called "integration_test_1"
    echo "Creating task"
    sh "curl -i -f -u 'tasks:redhat1' -H 'Content-Length: 0' -X POST http://tasks.csas-tasks-dev.svc:8080/ws/tasks/integration_test_1"

    // Retrieve task with id "1"
    echo "Retrieving tasks"
    sh "curl -i -f -u 'tasks:redhat1' -H 'Content-Length: 0' -X GET http://tasks.csas-tasks-dev.svc:8080/ws/tasks/1"

    // Delete task with id "1"
    echo "Deleting tasks"
    sh "curl -i -f -u 'tasks:redhat1' -H 'Content-Length: 0' -X DELETE http://tasks.csas-tasks-dev.svc:8080/ws/tasks/1"
  }
}
// Convenience Functions to read variables from the pom.xml
// Do not change anything below this line.
// --------------------------------------------------------
def getVersionFromPom(pom) {
  def matcher = readFile(pom) =~ '<version>(.+)</version>'
  matcher ? matcher[0][1] : null
}
def getGroupIdFromPom(pom) {
  def matcher = readFile(pom) =~ '<groupId>(.+)</groupId>'
  matcher ? matcher[0][1] : null
}
def getArtifactIdFromPom(pom) {
  def matcher = readFile(pom) =~ '<artifactId>(.+)</artifactId>'
  matcher ? matcher[0][1] : null
}
