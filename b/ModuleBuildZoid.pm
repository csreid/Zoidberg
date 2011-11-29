package # hide from pause indexer
	ModuleBuildZoid;

use strict;

require Module::Build;
require File::Spec;

our @ISA = qw/Module::Build/;

sub MyInit {
	my $self = shift;

	# setup cleaner
	$self->add_to_cleanup(qw#Makefile Zoidberg/ bin/zoid#);

	# setup script
	$self->script_files('bin/zoid');

	# setup man1 docs to be used
	push @{$$self{properties}{bindoc_dirs}}, 'man1';

	# setup handlers to be called
	unshift @{$$self{properties}{build_elements}}, 'MyPre';
	push @{$$self{properties}{build_elements}}, 'MyPost';

	# setup etc share and doc to be used
	push @{$$self{properties}{install_types}}, qw/etc share doc/;
	for my $k (keys %{$$self{properties}{install_sets}}) {
		my $s = $$self{properties}{install_sets}{$k};

		my ($vol, $dir) = File::Spec->splitpath($$s{bin}, 1);
		my @dirs = File::Spec->splitdir($dir);
		pop @dirs; # lose /bin/
		$$s{share} = File::Spec->catpath($vol,
			File::Spec->catdir(@dirs, qw/share zoid/) );
		$$s{doc} = File::Spec->catpath($vol,
			File::Spec->catdir(@dirs, qw/doc zoid/) );
		$$s{etc} = File::Spec->catpath($vol,
			File::Spec->catdir(@dirs, 'etc') ); # try relative etc
		$$s{etc} = File::Spec->catpath($vol,
			File::Spec->catdir('', 'etc') ) unless -d $$s{etc}; # else /etc

	}
}


sub process_MyPre_files {
	my $self = shift;

	my $blib = $self->blib;
	my ($zoidPL, $testPL) = map {File::Spec->catfile(@$_)} (['b','zoid.PL'], ['b','test.PL']);

	$self->run_perl_script($zoidPL); # not using up2date due to dynamic config
	$self->run_perl_script($testPL);

	$self->copy_if_modified( from => $_, to => File::Spec->catfile($blib, 'doc', $_) )
		for qw/Changes README/;

	# (using the manifest here is pure laziness)
	open MAN, 'MANIFEST' || die 'Could not read MANIFEST';
	my @files = map {chomp; $_} grep /^(etc|doc|share)\//, (<MAN>);
	close MAN || die 'Could not read MANIFEST';

	$self->copy_if_modified( from => $_, to => File::Spec->catfile($blib, $_) )
		for map {$self->localize_file_path($_)} @files;
}

sub process_MyPost_files {
	my $self = shift;
	$self->run_perl_script( File::Spec->catfile('b', 'Config.PL') ); # not using up2date due to dynamic config
	$self->run_perl_script( File::Spec->catfile('b', 'Strip.PL') )
		if $self->{args}{strip};
}

# overloaded methods

sub man1page_name { # added the s/\.pod$//
	my $self = shift;
	my $name =  File::Basename::basename( shift );
	$name =~ s/\.pod$//;
	return $name;
}

sub install_base_relative { # Added etc, share and doc paths
	my ($self, $type) = @_;
	my %map = (
		lib     => ['lib'],
		arch    => ['lib', $self->{config}{archname}],
		bin     => ['bin'],
		script  => ['script'],
		bindoc  => ['man', 'man1'],
		libdoc  => ['man', 'man3'],
		etc     => ['etc'],
		share   => ['share', 'zoid'],
		doc     => ['doc', 'zoid']
	);
	return unless exists $map{$type};
	return File::Spec->catdir(@{$map{$type}});
}

=head1 NAME

ModuleBuildZoid - a custom subclass of Module::Build

=head1 DESCRIPTION

Class with some custom stuff to overloaded L<Module::Build>
for building Zoidberg.

=cut