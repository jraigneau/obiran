**A propos**

Sauvegarder régulièrement les données est un réflexe à avoir car le monde numérique peut être impitoyable: imaginez toutes vos photos depuis 5 ans disparaissant suite à un disque dur cassé !

Le mieux est d'automatiser cette tâche, aussi j'ai développé OBIRAN - Outil de Backup Incrémental en Ruby ('Obiran Kenobi, vous êtes notre seul espoir' (Princesse Leila, Starwars IV) ).

Ce script en langage Ruby permet d'effectuer des sauvegardes incrémentales en utilisant rsync, ssh et cp.
	
   * Rsync permet de synchroniser deux répertoires.
   * ssh donne les accès à distance.
   * cp -al est utilisé pour faire des copies de répertoires _Hard-Link en anglais_ sans perdre trop de place.

**Principe**

_Incrémental ?_

Ce script est très fortement inspiré des idées de synchronisation trouvées sur les pages suivantes:

  * [Backups using rsync](http://www.sanitarium.net/golug/rsync_backups.html) par Kevin Korb
  * [Easy Automated Snapshot-Style Backups with Linux and Rsync](http://www.mikerubel.org/computers/rsync_snapshots/) par Mike Rubel


Le principe est de faire des sauvegardes incrémentales, c'est à dire ne sauvegarder que les différences d'un backup à l'autre. Ainsi la place consommée est bien moindre:

	tifauve@einstein:~/backup/obiran/turing$ du -shc *
	43G     20061016_170631
	514M    20061016_204921
	82M     20061017_205021
	397M    20061018_200001
	1,1G    20061018_202601
	45G     total

Dans l'exemple ci-dessous, la première sauvegarde prend 43Go mais l'espace occupé par les suivantes est bien inférieure. Cela permet de faire des sauvegardes fréquentes et complètes souvent.

_Un peu de magie_

Toutefois, ce qui est reproché à l'incrémental en général est le risque de perdre la première sauvegarde sur laquel sont basées les autres. Que neni !

En effet dans notre cas on utilise la commande cp -al qui permet de faire des 'hard-link', similaires aux symlinks (le célèbre ln -s). A l'inverse des symlinks qui crée un lien vers un fichier, le hard-link (ln -li pour les intimes) crée deux liens vers un seul et même fichier: supprimer un lien n'a aucune incidence sur l'autre lien et le fichier.

La commande cp -al permet donc de dupliquer deux répertoires sans occuper de place supplémentaire. En reprenant l'exemple ci-dessus, on peut constater que les répertoires sont en fait presque de la même taille (le dernier est plus gros suite à des changements importants)

	tifauve@einstein:~/backup/obiran/turing$ du -sh *
	43G     20061016_170631
	43G     20061016_204921
	43G     20061017_205021
	43G     20061018_200001
	44G     20061018_202601

Si le répertoire 'master' 20061016_170631 est supprimé, les autres répertoires conservent tout de même toutes les données.

_Et Rsync dans tout ça ?_

Rsync permet de synchroniser les fichiers: c'est cette commande qui va gérer les différences entre deux fichiers d'un jour à l'autre. Si aucune différence (modification, ajout ou suppression) n'est trouvée alors le fichier n'est pas copié à travers le réseau

**Conclusion**

L'association de ces deux commandes permet de faire des sauvegardes rapidement et en occupant un minimum de place.

