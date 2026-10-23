# @file src/server/seeder/faker.awk
# @description AWK faker library for generating synthetic seed data in ephemeral server databases.

# fake_name generates a random human first name.
# @param none
# @return A randomly selected name string.
function fake_name() {
    names[1]="Alice"; names[2]="Bob"; names[3]="Charlie"; names[4]="David"; names[5]="Eve"
    return names[int(rand()*5)+1]
}

# fake_email generates a random email address based on fake_name.
# @param none
# @return A randomly generated email address string.
function fake_email() {
    domains[1]="example.com"; domains[2]="test.org"; domains[3]="demo.net"
    return tolower(fake_name()) "@" domains[int(rand()*3)+1]
}

# fake_phone generates a random 7-digit phone number string.
# @param none
# @return A formatted phone number string (555-XXXX).
function fake_phone() {
    return sprintf("555-%04d", int(rand()*10000))
}

# fake_uuid generates a pseudo-UUID v4 string.
# @param none
# @return A 36-character UUID string.
function fake_uuid() {
    return sprintf("%04x%04x-%04x-%04x-%04x-%04x%04x%04x",
        rand()*65535, rand()*65535, rand()*65535,
        rand()*65535, rand()*65535, rand()*65535,
        rand()*65535, rand()*65535)
}

# fake_text generates a short synthetic text string for titles or comments.
# @param prefix - Label prefix for the generated text.
# @param idx - Numeric index suffix.
# @return A formatted synthetic text string.
function fake_text(prefix, idx) {
    return sprintf("%s %d by %s", prefix, idx, fake_name())
}

# pool_add appends an entity ID to the in-memory Entity Pool for a given model tier.
# @param entity - The entity pool name (e.g., "users", "posts", "comments").
# @param id - The primary key UUID to record.
# @return The new count of cached IDs for the entity pool.
function pool_add(entity, id) {
    ENTITY_POOL_COUNT[entity]++
    ENTITY_POOL[entity, ENTITY_POOL_COUNT[entity]] = id
    return ENTITY_POOL_COUNT[entity]
}

# pool_random selects a random valid foreign key ID from the parent's Entity Pool.
# @param entity - The parent entity pool name (e.g., "users", "posts").
# @return A cached parent UUID string, or an empty string if the pool is empty.
function pool_random(entity,    cnt, pick) {
    cnt = ENTITY_POOL_COUNT[entity] + 0
    if (cnt <= 0) return ""
    pick = int(rand() * cnt) + 1
    return ENTITY_POOL[entity, pick]
}

# seed_relational_graph emits SQL INSERT statements in topological order (Users -> Posts -> Comments) using realistic 10:50:200 generation ratios.
# @param user_cnt - Number of Tier 1 User records to generate (default: 10).
# @param post_cnt - Number of Tier 2 Post records to generate (default: 50).
# @param comment_cnt - Number of Tier 3 Comment records to generate (default: 200).
# @return Returns 0 after printing SQL INSERT statements.
function seed_relational_graph(user_cnt, post_cnt, comment_cnt,    i, id, uid, pid) {
    if (user_cnt <= 0) user_cnt = 10
    if (post_cnt <= 0) post_cnt = 50
    if (comment_cnt <= 0) comment_cnt = 200
    for (i = 1; i <= user_cnt; i++) {
        id = fake_uuid()
        pool_add("users", id)
        print "INSERT INTO users (id, name, email) VALUES ('" id "', '" fake_name() "', '" fake_email() "');"
    }
    for (i = 1; i <= post_cnt; i++) {
        id = fake_uuid()
        uid = pool_random("users")
        pool_add("posts", id)
        print "INSERT INTO posts (id, user_id, title) VALUES ('" id "', '" uid "', '" fake_text("Post", i) "');"
    }
    for (i = 1; i <= comment_cnt; i++) {
        id = fake_uuid()
        uid = pool_random("users")
        pid = pool_random("posts")
        pool_add("comments", id)
        print "INSERT INTO comments (id, post_id, user_id, body) VALUES ('" id "', '" pid "', '" uid "', '" fake_text("Comment", i) "');"
    }
    return 0
}

