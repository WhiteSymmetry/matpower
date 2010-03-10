function [varargout] = dcopf(varargin)
%DCOPF  Solves a DC optimal power flow.
%   This is a simple wrapper function around OPF that sets the PF_DC
%   option to 1 before calling OPF.
%   See OPF for the details of input and output arguments.
%
%   See also RUNDCOPF.

%   MATPOWER
%   $Id$
%   by Ray Zimmerman, PSERC Cornell
%   Copyright (c) 1996-2010 by Power System Engineering Research Center (PSERC)
%   See http://www.pserc.cornell.edu/matpower/ for more info.

[mpc, mpopt] = opf_args(varargin{:});
mpopt = mpoption(mpopt, 'PF_DC', 1);
[varargout{1:nargout}] = opf(mpc, mpopt);
