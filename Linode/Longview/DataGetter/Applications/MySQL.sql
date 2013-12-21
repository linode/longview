SHOW /*!50002 GLOBAL */ STATUS
WHERE Variable_name IN ("Com_select", "Com_insert", "Com_update", "Com_delete",
                        "slow_queries", "Bytes_sent", "Bytes_received",
                        "Connections", "Max_used_connections",
                        "Aborted_Connects", "Aborted_Clients",
                        "Qcache_queries_in_cache", "Qcache_hits",
                        "Qcache_inserts", "Qcache_not_cached",
                        "Qcache_lowmem_prunes");
SHOW /*!50002 GLOBAL */ VARIABLES LIKE "version";
