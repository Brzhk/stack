import com.cloudbees.jenkins.plugins.amazonecs.ECSCloud
import com.cloudbees.jenkins.plugins.amazonecs.ECSTaskTemplate
import com.sun.xml.internal.ws.policy.privateutil.PolicyUtils
import hudson.BulkChange
import hudson.FilePath
import hudson.model.Node
import hudson.plugins.git.GitSCM
import hudson.security.FullControlOnceLoggedInAuthorizationStrategy
import hudson.security.HudsonPrivateSecurityRealm
import hudson.security.SecurityRealm
import hudson.security.csrf.DefaultCrumbIssuer
import jenkins.CLI
import jenkins.model.Jenkins
import jenkins.model.JenkinsLocationConfiguration
import jenkins.security.s2m.AdminWhitelistRule
import org.jenkinsci.plugins.docker.commons.credentials.DockerRegistryEndpoint
import org.jenkinsci.plugins.pipeline.modeldefinition.config.GlobalConfig

import java.util.logging.Logger

def logger = Logger.getLogger("")

int defined_slaveport = 50000

def taskTemplateName = "java"
def taskLabel = "java"
def taskImage = "cloudbees/jnlp-slave-with-java-build-tools:latest"
def taskRemoteFSRoot = "/home/jenkins"
def tasklogDriver = "journald"
def taskCpu = 512
def taskMemory = 0
def taskMemoryReservation = 2048
def privileged = false

def dindTaskTemplateName = "dind"
def dindTaskLabel = "dind"
def dindTaskImage = "brzhk/jenkins-dind-jnlp-slave"
def dindTaskRemoteFSRoot = "/home/jenkins"
def dindTasklogDriver = "journald"
def dindTaskCpu = 512
def dindTaskMemory = 0
def dindTaskMemoryReservation = 2048
def dindPrivileged = true

def awsAccountId = 759204445141
def clusterName = "forge"
def jenkinsInternalUrl = "jenkins.stack.local"
def cloudName = clusterName
def cloudClusterArn = "arn:aws:ecs:eu-west-1:" + awsAccountId + ":cluster/" + clusterName
def tunnel = "${jenkinsInternalUrl}:${defined_slaveport}"
def jenkinsUrl = "http://" + jenkinsInternalUrl + "/"
def emptyCreds = ""
def regionName = "eu-west-1"
def slaveTimeoutInSeconds = 900


final String ADMIN_USERNAME = 'Brzhk'
Jenkins instance = Jenkins.getInstance()
final FilePath ADMIN_PASSWORD_FILE = instance.getRootPath().child('secrets/initialAdminPassword')
SecurityRealm securityRealm = instance.getSecurityRealm() ? instance.getSecurityRealm() : new HudsonPrivateSecurityRealm(false)


if (securityRealm instanceof HudsonPrivateSecurityRealm
        && securityRealm.getAllUsers().isEmpty()) {

    HudsonPrivateSecurityRealm defaultSecurityRealm = securityRealm

    logger.info "--> creating ${ADMIN_USERNAME} local user"
    String generatedPassword = UUID.randomUUID().toString().replace('-', '').toLowerCase(Locale.ENGLISH)
    new BulkChange(instance).withClosable {

        defaultSecurityRealm.createAccount(ADMIN_USERNAME, generatedPassword)
//        User admin = defaultSecurityRealm.createAccount(ADMIN_USERNAME, generatedPassword)
//        assert ExtensionList.lookup(PermissionAdder.class).any {
//            it.add(instance.getAuthorizationStrategy(), admin, Jenkins.ADMINISTER)
//        }: "Cannot give the ADMINISTER authority to the ${ADMIN_USERNAME} user"

        ADMIN_PASSWORD_FILE.touch(System.currentTimeMillis())
        ADMIN_PASSWORD_FILE.chmod(0640)
        ADMIN_PASSWORD_FILE.write(generatedPassword + System.lineSeparator(), 'UTF-8')

        logger.info "--> setting full control once logger authorization strategy"
        FullControlOnceLoggedInAuthorizationStrategy strategy = new FullControlOnceLoggedInAuthorizationStrategy()
        strategy.allowAnonymousRead = false
        instance.setAuthorizationStrategy(strategy)

        logger.info "--> disabling CLI remote access"
        CLI.get().setEnabled(false)

        logger.info "--> creating crumb issuer"
        DefaultCrumbIssuer defaultCrumbIssuer = new DefaultCrumbIssuer(true)
        instance.crumbIssuer = defaultCrumbIssuer
        instance.setSecurityRealm(defaultSecurityRealm)

        logger.info "--> enabling slave access control mechanism"
        instance.getInjector().getInstance(AdminWhitelistRule.class)
                .setMasterKillSwitch(false)

        logger.info "--> setting slave port"
        instance.setSlaveAgentPort(defined_slaveport)

        def jenkinsLocationConfiguration = JenkinsLocationConfiguration.get()

        jenkinsLocationConfiguration.setAdminAddress("Brzhk <berzehk@gmail.com>")
        jenkinsLocationConfiguration.setUrl("https://jenkins.brzhk.wtf/")
        jenkinsLocationConfiguration.save()

        instance.setLabelString("master")
        instance.setMode(Node.Mode.EXCLUSIVE)
        instance.setScmCheckoutRetryCount(2)
        instance.setSystemMessage("-- Press START --")

        GitSCM.DescriptorImpl gitDesc = Jenkins.instance.getExtensionList(GitSCM.DescriptorImpl.class)[0]
        gitDesc.globalConfigEmail = "berzehk@gmail.com"
        gitDesc.globalConfigName = "Brzhk"
        gitDesc.createAccountBasedOnEmail = false
        gitDesc.save()

        GlobalConfig pipelineCfg = GlobalConfig.get()
        pipelineCfg.dockerLabel = dindTaskLabel
        pipelineCfg.setRegistry(new DockerRegistryEndpoint(null, null))
        pipelineCfg.save()

        logger.info "--> configuring java slave agent"
        List<ECSTaskTemplate.LogDriverOption> logDriverOptions = Collections.singletonList(new ECSTaskTemplate.LogDriverOption("tag", taskTemplateName))
        List<ECSTaskTemplate.EnvironmentEntry> environments = Collections.EMPTY_LIST
        List<ECSTaskTemplate.ExtraHostEntry> extraHosts = Collections.EMPTY_LIST
        List<ECSTaskTemplate.MountPointEntry> mountPoints = Collections.EMPTY_LIST
        ECSTaskTemplate taskTemplate = new ECSTaskTemplate(taskTemplateName, taskLabel, taskImage, taskRemoteFSRoot, taskMemory, taskMemoryReservation, taskCpu, privileged, logDriverOptions, environments, extraHosts, mountPoints)
        taskTemplate.setLogDriver(tasklogDriver)

        logger.info "--> configuring dind slave agent"
        List<ECSTaskTemplate.LogDriverOption> dindLogDriverOptions = Collections.singletonList(new ECSTaskTemplate.LogDriverOption("tag", taskTemplateName))
        List<ECSTaskTemplate.EnvironmentEntry> dindEnvironments = Collections.EMPTY_LIST
        List<ECSTaskTemplate.ExtraHostEntry> dindExtraHosts = Collections.EMPTY_LIST
        List<ECSTaskTemplate.MountPointEntry> dindMountPoints = Collections.singletonList(new ECSTaskTemplate.MountPointEntry('varlibdocker', '', '/var/lib/docker', false))
        ECSTaskTemplate dindTaskTemplate = new ECSTaskTemplate(dindTaskTemplateName, dindTaskLabel, dindTaskImage, dindTaskRemoteFSRoot, dindTaskMemory, dindTaskMemoryReservation, dindTaskCpu, dindPrivileged, dindLogDriverOptions, dindEnvironments, dindExtraHosts, dindMountPoints)
        dindTaskTemplate.setLogDriver(dindTasklogDriver)


        ECSCloud ecsCloud = new ECSCloud(cloudName, Arrays.asList(taskTemplate, dindTaskTemplate), emptyCreds, cloudClusterArn, regionName, jenkinsUrl, slaveTimeoutInSeconds)
        ecsCloud.tunnel = tunnel
        instance.clouds.add(ecsCloud)

        it.commit()

        if (ADMIN_PASSWORD_FILE.exists()) {
            String setupKey = ADMIN_PASSWORD_FILE.readToString().trim()
            logger.info("""
                *************************************************************
                *************************************************************
                *************************************************************
                    
                Jenkins initial setup is required. An admin user has been 
                created and a password generated. Please use the following 
                password to proceed to installation:
                    
                    ${setupKey} 
                    
                This may also be found at: ${ADMIN_PASSWORD_FILE.getRemote()}
                    
                *************************************************************
                *************************************************************
                *************************************************************""")
        }
    }
} else
    logger.info "Admin found"