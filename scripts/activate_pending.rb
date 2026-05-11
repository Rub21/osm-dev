# Auto-activate pending users (skips email confirmation in dev).
# Run in a loop from start.sh.

User.where(:status => "pending").find_each(&:activate!)
