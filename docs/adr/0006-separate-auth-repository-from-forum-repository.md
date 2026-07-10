# Separate authentication from the forum repository

AuthRepository owns ArkWeb authorization, temporary RSA material, HUKS-backed Authenticated Session persistence, restoration, and logout. ForumRepository owns only forum API operations and receives the current session through a narrower transport dependency, keeping cryptographic lifecycle concerns out of Topic, Post, and Reply handling.
