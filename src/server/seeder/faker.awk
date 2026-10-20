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
