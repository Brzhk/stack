import com.cloudbees.jenkins.plugins.amazonecs.ECSCloud
import com.cloudbees.jenkins.plugins.amazonecs.ECSTaskTemplate
import hudson.model.Saveable
import hudson.security.FullControlOnceLoggedInAuthorizationStrategy
import hudson.security.HudsonPrivateSecurityRealm
import hudson.security.csrf.DefaultCrumbIssuer
import hudson.plugins.git.GitSCM
import hudson.tasks.Maven
import hudson.util.DescribableList
import jenkins.CLI
import jenkins.model.Jenkins
import jenkins.model.JenkinsLocationConfiguration
import jenkins.security.s2m.AdminWhitelistRule
import jenkins.slaves.JnlpSlaveAgentProtocol4

import java.util.logging.Logger

int defined_slaveport = 50000

def logger = Logger.getLogger("")
def instance = Jenkins.getInstance()
def hudsonRealm = new HudsonPrivateSecurityRealm(false)
def users = hudsonRealm.getAllUsers()
if (!users || users.empty) {
    println "No Users"

    println "--> creating local user 'admin'"
    hudsonRealm.createAccount('brzhk', 'brzhkbrzhk')
    println "--> setting full control once logger authorization strategy"

    def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
    strategy.allowAnonymousRead = false
    instance.setAuthorizationStrategy(strategy)

    println "--> disabling CLI remote access"
    CLI.get().setEnabled(false)

    println "--> creating crumb issuer"
    DefaultCrumbIssuer defaultCrumbIssuer = new DefaultCrumbIssuer(true)
    instance.crumbIssuer = defaultCrumbIssuer
    instance.setSecurityRealm(hudsonRealm)

    println "--> enabling slave access control mechanism"
    instance.getInjector().getInstance(AdminWhitelistRule.class)
            .setMasterKillSwitch(false)

    def current_slaveport = instance.getSlaveAgentPort()

    if (current_slaveport != defined_slaveport) {
        println "--> setting slave port"
        instance.setSlaveAgentPort(defined_slaveport)
        logger.info("Slaveport set to " + defined_slaveport)

        instance.setAgentProtocols(Collections.singleton(JnlpSlaveAgentProtocol4.name))
    }


    def jenkinsLocationConfiguration = JenkinsLocationConfiguration.get()

    jenkinsLocationConfiguration.setAdminAddress("Brzhk <berzehk@gmail.com>")
    jenkinsLocationConfiguration.setUrl("https://jenkins.brzhk.wtf/")
    jenkinsLocationConfiguration.save()


    GitSCM.DescriptorImpl gitDesc = Jenkins.instance.getExtensionList(GitSCM.DescriptorImpl.class)[0]
    gitDesc.globalConfigEmail = "berzehk@gmail.com"
    gitDesc.globalConfigName = "Brzhk"
    gitDesc.createAccountBasedOnEmail = false
    gitDesc.save()

    println "--> configuring slave management"

    def taskTemplateName = "ecs-java"
    def taskLabel = "ecs-java"
    def taskImage = "cloudbees/jnlp-slave-with-java-build-tools"
    def taskRemoteFSRoot = "/home/jenkins"
    def tasklogDriver = "journald"
    def taskCpu = 512
    def taskMemory = 0
    def taskMemoryReservation = 2048
    def privileged = false
    List<ECSTaskTemplate.LogDriverOption> logDriverOptions = Collections.singletonList(new ECSTaskTemplate.LogDriverOption("tag", taskTemplateName))
    List<ECSTaskTemplate.EnvironmentEntry> environments = Collections.EMPTY_LIST
    List<ECSTaskTemplate.ExtraHostEntry> extraHosts = Collections.EMPTY_LIST
    List<ECSTaskTemplate.MountPointEntry> mountPoints = Collections.EMPTY_LIST
    ECSTaskTemplate taskTemplate = new ECSTaskTemplate(taskTemplateName, taskLabel, taskImage, taskRemoteFSRoot, taskMemory, taskMemoryReservation, taskCpu, privileged, logDriverOptions, environments, extraHosts, mountPoints);
    taskTemplate.setLogDriver(tasklogDriver)

    def awsAccountId = 759204445141
    def clusterName = "forge"
    def jenkinsInternalUrl = "jenkins.stack.local"
    def cloudName = clusterName
    def cloudClusterArn = "arn:aws:ecs:eu-west-1:" + awsAccountId + ":cluster/" + clusterName
    def tunnel = jenkinsInternalUrl + ":50000"
    def jenkinsUrl = "http://" + jenkinsInternalUrl + ".local/"
    def emptyCreds = ""
    def regionName = "eu-west-1"
    def slaveTimeoutInSeconds = 900

    ECSCloud ecsCloud = new ECSCloud(cloudName, Collections.singletonList(taskTemplate), emptyCreds, cloudClusterArn, regionName, jenkinsUrl, slaveTimeoutInSeconds)
    ecsCloud.tunnel = tunnel

    instance.clouds.add(ecsCloud)

} else
    println "Admin found"

instance.save()