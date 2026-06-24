# awk faker library
function fake_name() {
    names[1]="Alice"; names[2]="Bob"; names[3]="Charlie"; names[4]="David"; names[5]="Eve"
    return names[int(rand()*5)+1]
}
function fake_email() {
    domains[1]="example.com"; domains[2]="test.org"; domains[3]="demo.net"
    return tolower(fake_name()) "@" domains[int(rand()*3)+1]
}
function fake_phone() {
    return sprintf("555-%04d", int(rand()*10000))
}
function fake_uuid() {
    # very simple pseudo-uuid
    return sprintf("%04x%04x-%04x-%04x-%04x-%04x%04x%04x",
        rand()*65535, rand()*65535, rand()*65535,
        rand()*65535, rand()*65535, rand()*65535,
        rand()*65535, rand()*65535)
}
