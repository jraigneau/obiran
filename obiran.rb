#!/usr/bin/ruby -w

# OBIRAN (kenobi! "Vous êtes mon seul espoir" (Princesse Leila, Starwars IV))
# Outil de Backup Incrémental en Ruby 

# Permet de sauvegarder en utilisant rsync + "hard link" pour l'incrémental + ssh
# Développé par J.RAIGNEAU - julien@raigneau.net - http://labs.tifauve.net
# v0.6 


#== Variables utiles ==
require 'yaml' #pour la conf

ENV['LC_ALL']   = nil
ENV['LC_CTYPE'] = 'fr_FR.UTF-8'

#fichier de configuration
configFile = ARGV[0] ? ARGV[0] : "obiran-conf.yml"

#chargement du fichier de configuration
config = YAML::load(IO.read(configFile))

#Répertoire master côté backup (contient toutes les itérations)
backupmasterdir = config['backupmasterdir']

#Nombre d'itérations à conserver
iterations = config['iterations']

#Répertoires à sauvegarder (ne pas mettre de / à la fin!)
myDirs = config['dirs2backup']

#config SSH
sshIpDestination = config['ssh_ipDestination']
sshUser = config['ssh_user']
sshPort = config['ssh_port']
sshOptions = config['ssh_options']

#Répertoires à ne pas sauverder 
excludedDirs = config['excludedDirs']

#suppression des répertoires exclus?
#utilisé dans ssh
if config['deleteExcludedDirs']
  deleteExcludedDirs = "--delete-excluded"
else
  deleteExcludedDirs = ""
end

#Emplacement binaire Rsync sur Remote
rsyncPath = config['rsyncPath']

#Nom du répertoire dans lequel sera stocké la nouvelle itération: AAAAMMJJ_HHMM
backupdir = (Time.now).strftime("%Y%m%d_%H%M%S")

#fichier de log
$log = "/tmp/obiran_#{backupdir}.log"
$logFile = File.new($log, "w+")

#== fonctions annexes ==
#Affiche un array
def displayArray(arr)
  text = "\t{"
  arr.each {|x| text = text + "\n\t"+ x }
  text = text + "\n\t}"
  return text
end

#fonction pour logguer les actions
def logThis(txt)
  $logFile.puts txt
  puts txt
end


#Création du fichier de log
logThis "\t\tOBIRAN - Outil de Backup Incrémental en Ruby"
logThis "\t\t============================================\n\n"
logThis "Répertoires à sauvegarder: \n#{displayArray(myDirs)}"
logThis "Motifs à exclure: \n#{displayArray(excludedDirs)}"
logThis "Nombre de répertoires conservés: #{iterations}"
logThis "Répertoire de stockage des sauvegardes: #{backupmasterdir}"
logThis "Début du backup: " + (Time.now).strftime("%d/%m/%Y %H:%M:%S")
logThis "\n============================================\n\n"

#Récupération des répertoires par ssh
dirs = `ssh -p #{sshPort} #{sshOptions} #{sshUser}@#{sshIpDestination} "ls -r1 #{backupmasterdir}"`
dirs=dirs.split("\n") #transformation en array
dirs.delete_if{|x| /[0-9]_[0-9]/.match(x) == nil} #suppression des répertoires qui ne sont pas du type AAAAMMJJ_HHMM
logThis "Répertoires de sauvegarde actuellement sur le serveur: \n#{displayArray(dirs)}"

## Etape 1: Supprimer les répertoires incrémentaux trop vieux sur la machine de backup (variable iterations)
if dirs.length == iterations
	#Suppression du répertoire
	oldbackupdir = dirs[iterations-1]
	logThis "Le répertoire #{oldbackupdir} est trop vieux, il va être effacé"
	`ssh -p #{sshPort} #{sshOptions} #{sshUser}@#{sshIpDestination} "rm -rf #{backupmasterdir}/#{oldbackupdir}"`
end

## Etape 2: Préparer l'incrémental sur la machine de backup
# Utilisation de cp -al sur le répertoire le plus récent pour créer le nouveau répertoire + création d'un repertoire 'current'
if dirs.length != 0
    lastbackupdir = dirs[0] #récupération du répertoire le plus récent
    logThis "Le répertoire #{lastbackupdir} va servir de référence pour le rsync"
	`ssh -p #{sshPort} #{sshOptions} #{sshUser}@#{sshIpDestination} "cp -al #{backupmasterdir}/#{lastbackupdir} #{backupmasterdir}/#{backupdir};rm #{backupmasterdir}/current;ln -s #{backupmasterdir}/#{backupdir}/ #{backupmasterdir}/current; rm #{backupmasterdir}/current/obiran*.log"`
else #si premier backup, pas de cp -al et moins d'opération
	logThis "Pas de backup auparavant: création du premier répertoire backup"
	logThis "Le rsync peut prendre plusieurs dizaines de minutes..."
	`ssh -p #{sshPort} #{sshOptions} #{sshUser}@#{sshIpDestination} "mkdir #{backupmasterdir}/#{backupdir};ln -s #{backupmasterdir}/#{backupdir}/ #{backupmasterdir}/current"`
end

#ssh "--exclude="
excludedDirs=excludedDirs.collect { |x| "--exclude=#{x}"}.join(" ")

## Etape 3: début des rsync, lancés avec priorité basse (nice -n 19)
myDirs.each do |myDir|
	logThis "Synchronisation de #{myDir}..."
	`nice -n 19 rsync -az --delete #{excludedDirs} #{deleteExcludedDirs} --rsync-path=#{rsyncPath} -e "ssh -p #{sshPort} #{sshOptions}" #{myDir} #{sshUser}@#{sshIpDestination}:#{backupmasterdir}/#{backupdir}`
end

logThis "\n============================================"
logThis "Fin du backup: " + (Time.now).strftime("%d/%m/%Y %H:%M:%S")

$logFile.close

#Envoi du fichier de log sur le serveur de backup
`scp -P #{sshPort} #{sshOptions} #{$log} #{sshUser}@#{sshIpDestination}:#{backupmasterdir}/#{backupdir}/`
