function data = psse_parse_section(records, sections, s, verbose, label, template)
%PSSE_PARSE_SECTION  Parses the data from a section of a PSS/E RAW data file
%   DATA = PSSE_PARSE_SECTION(RECORDS, SECTIONS, SIDX, VERBOSE, LABEL, TEMPLATE)
%   DATA = PSSE_PARSE_SECTION(RECORDS, SECTIONS, SIDX, VERBOSE, LABEL)
%   DATA = PSSE_PARSE_SECTION(RECORDS, SECTIONS, SIDX, VERBOSE)
%   DATA = PSSE_PARSE_SECTION(RECORDS, SECTIONS, SIDX)
%   DATA = PSSE_PARSE_SECTION(RECORDS, VERBOSE, LABEL, TEMPLATE)
%   DATA = PSSE_PARSE_SECTION(RECORDS, VERBOSE, LABEL)
%   DATA = PSSE_PARSE_SECTION(RECORDS, VERBOSE)
%   DATA = PSSE_PARSE_SECTION(RECORDS)
%
%   Inputs:
%       RECORDS :   a cell array of strings returned by PSSE_READ
%       SECTIONS :  a struct array returned by PSSE_READ
%       SIDX :      (optional) index if the section to be read
%                   if included, the RECORD indices are taken from
%                   SECTIONS(SIDX), otherwise use all RECORDS
%       VERBOSE :   1 to display progress info, 0 (default) otherwise
%       LABEL :     (optional) name for the section, to be compared with
%                   the section name typically found in the
%                   END OF <LABEL> DATA comment at the end of each section
%       TEMPLATE :  (optional) string of characters indicating how to
%                   interpret the type of the corresponding column, options
%                   are as follows:
%               d, f or g : integer floating point number to be converted
%                   via SSCANF with %d, %f or %g, respectively.
%               D, F or G : integer floating point number, possibly enclosed
%                   in single or double quotes, to be converted via
%                   SSCANF with %d, %f or %g, respectively.
%               c or s : character or string, possibly enclosed in single
%                   or double quotes, which are stripped from the string
%           Note:   Data columns in RECORDS that have no valid corresponding
%                   entry in TEMPLATE (beyond end of TEMPLATE, or a character
%                   other than those listed, e.g. '.') are returned in DATA.txt
%                   with  no conversion. TEMPLATE entries for which there is
%                   no corresponding column in RECORDS are returned as NaN and
%                   empty, respectively, in DATA.num and DATA.txt.
%
%   Output:
%       DATA :      a struct with two fields:
%           num :   matrix containing the numeric data for the section, for
%                   columns with no numeric data, num contain NaNs.
%           txt :   a cell array containing the non-numeric (char/string)
%                   data for the section, for columns with numeric data,
%                   txt entries are empty
%
%   See also PSSE2MPC, PSSE_PARSE

%   MATPOWER
%   $Id$
%   by Ray Zimmerman, PSERC Cornell
%   Copyright (c) 2014 by Power System Engineering Research Center (PSERC)
%
%   This file is part of MATPOWER.
%   See http://www.pserc.cornell.edu/matpower/ for more info.
%
%   MATPOWER is free software: you can redistribute it and/or modify
%   it under the terms of the GNU General Public License as published
%   by the Free Software Foundation, either version 3 of the License,
%   or (at your option) any later version.
%
%   MATPOWER is distributed in the hope that it will be useful,
%   but WITHOUT ANY WARRANTY; without even the implied warranty of
%   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
%   GNU General Public License for more details.
%
%   You should have received a copy of the GNU General Public License
%   along with MATPOWER. If not, see <http://www.gnu.org/licenses/>.
%
%   Additional permission under GNU GPL version 3 section 7
%
%   If you modify MATPOWER, or any covered work, to interface with
%   other modules (such as MATLAB code and MEX-files) available in a
%   MATLAB(R) or comparable environment containing parts covered
%   under other licensing terms, the licensors of MATPOWER grant
%   you additional permission to convey the resulting work.

%% defaults
if nargin < 2
    have_sections = 0;
    verbose = 0;
    template = '';
elseif isstruct(sections)
    have_sections = 1;
    if nargin < 6
        template = '';
        if nargin < 5
            label = '';
            if nargin < 4
                verbose = 0;
            else
                error('psse_parse_section: too few input arguments');
            end
        end
    end
else
    have_sections = 0;
    if nargin >= 4
        template = verbose;
    else
        template = '';
    end
    if nargin >= 3
        label = s;
    else
        label = '';
    end
    verbose = sections;
end

%% get relevant records, check section name
nt = length(template);
if have_sections
    nr = sections(s).last - sections(s).first + 1;
    recs = records(sections(s).first:sections(s).last);
    if ~isempty(sections(s).name) && ~strcmp(upper(label), sections(s).name)
        fprintf('-----  WARNING:  Expected section labeled: ''%s''\n', upper(label));
        fprintf('-----            Found section labeled:    ''%s''\n', sections(s).name);
    end
else
    nr = length(records);
    recs = records;
end
if verbose
    spacers = repmat('.', 1, 42-length(label));
    fprintf('Parsing %6d lines of %s data %s', nr, label, spacers);
end

if nr
    %% set up regexp to parse cols, comments of each record
    delim = '\s*(,|\s)\s*';
    non_quote_field = '[^''",\s/]+';
    single_quote_field = '''([^'']|'''')*''';
    double_quote_field = '"([^"]|"")*"';
    any_field = sprintf('(?<col>%s|%s|%s)', non_quote_field, single_quote_field, double_quote_field);
    pat = sprintf('%s%s|%s|(?<comment>/.*)?', any_field, delim, any_field);
    % pat = sprintf('%s%s|%s', any_field, delim, any_field);
    % pat = '(?<col>[^''",\s/]+|''([^'']|'''')*''|"([^"]|"")*")\s*(,|\s)\s*|(?<col>[^''",\s/]+|''([^'']|'''')*''|"([^"]|"")*")|(?<comment>/.*)?';

    %% set up functions for use with cellfun
    if have_fcn('octave')
        parser  = @(ln){{regexp(ln, pat, 'names')}};  %% parse cols, comments of each rec
        numcols = @(ss)length(ss{1}.col);   %% number of columns in each record
    else
        parser  = @(ln){regexp(ln, pat, 'names')};  %% parse cols, comments of each rec
        numcols = @(ss)length(ss);      %% number of columns in each record
    end

    %% parse the table into cell array of structs (with col, comment fields)
    dd = cellfun(parser, recs);

%     %% extract possible comments
%     if nargout > 1
%     %   extract_comment = @(n){n(end).comment};
%         if have_fcn('octave')
%             comment = cellfun(@(n){n{1}.comment(end)}, dd);
%         else
%             comment = cellfun(@(n){n(end).comment}, dd);
%         end
%     end

    %% find max number of columns
    nc = cellfun(numcols, dd);      %% number of columns
    ncmax = max(nc);
    ncmin = min(nc);

    %% extract data by column
    % nc = length(dd{1});
    % if nc && isempty(dd{1}(nc).col)   %% comment present
    %   nc = nc - 1;                %% reduce number of columns by 1 to discard
    % end
    data.num = NaN(nr, max(ncmax, nt));
    data.txt = cell(nr, max(ncmax, nt));
    for c = 1:ncmax
        %% template for conversion?
        if c <= nt
            t = template(c);
        else
            t = '';
        end
        if have_fcn('octave')   %% running under Octave
            switch t
                case {'d', 'f', 'g', 'D', 'F', 'G'} %% numeric data
                    if t == upper(t)                %% possibly quoted
                        xc_fcn  = @(n)extract_col_qnum_octave(n, c, lower(t));
                    else                            %% not quoted (more efficient)
                        if c <= ncmin
                            xc_fcn  = @(n)sscanf(n{1}.col{c}, ['%' t]);
                        else
                            xc_fcn  = @(n)extract_col_num_octave(n, c, t);
                        end
                    end
                case {'s', 'c'}
                    xc_fcn  = @(n){extract_col_dequote_octave(n, c)};
                otherwise
                    if c <= ncmin
                        xc_fcn  = @(n)n{1}.col(c);
                    else
                        xc_fcn  = @(n){extract_col_octave(n, c)};
                    end
            end
        else                    %% running under Matlab
            switch t
                case {'d', 'f', 'g', 'D', 'F', 'G'} %% numeric data
                    if t == upper(t)                %% possibly quoted
                        xc_fcn  = @(n)extract_col_qnum(n, c, lower(t));
                    else                            %% not quoted (more efficient)
                        if c <= ncmin
                            xc_fcn  = @(n)sscanf(n(c).col, ['%' t]);
                        else
                            xc_fcn  = @(n)extract_col_num(n, c, t);
                        end
                    end
                case {'s', 'c'}
                    xc_fcn  = @(n){extract_col_dequote(n, c)};
                otherwise
                    if c <= ncmin
                        xc_fcn  = @(n){n(c).col};
                    else
                        xc_fcn  = @(n){extract_col(n, c)};
                    end
            end
        end
        switch upper(t)
            case {'D', 'F', 'G'}
                data.num(:, c) = cellfun(xc_fcn, dd);
            otherwise
                data.txt(:, c) = cellfun(xc_fcn, dd);
        end
    end
else
    data.num = NaN(nr, nt);
    data.txt = cell(nr, nt);
end
if verbose
    fprintf(' done.\n');
%     if have_sections
%         fprintf('%s\n', upper(label));
%         fprintf('%s\n', sections(s).name);
%     end
end

%%---------------------------------------------------------------------
function str = extract_col(n, c)
if c <= length(n)
    str = n(c).col;
else
    str = '';
end

%%---------------------------------------------------------------------
function str = extract_col_octave(n, c)
if c <= length(n{1}.col)
    str = n{1}.col{c};
else
    str = '';
end

%%---------------------------------------------------------------------
function str = extract_col_dequote(n, c)
if c <= length(n)
    str = n(c).col;
    if ~isempty(str) && (str(1) == '''' || str(1) == '"')
        str = str(2:end-1);
    end
else
    str = '';
end

%%---------------------------------------------------------------------
function str = extract_col_dequote_octave(n, c)
if c <= length(n{1}.col)
    str = n{1}.col{c};
    if ~isempty(str) && (str(1) == '''' || str(1) == '"')
        str = str(2:end-1);
    end
else
    str = '';
end

%%---------------------------------------------------------------------
function num = extract_col_num(n, c, t)
if c <= length(n)
    num = sscanf(n(c).col, ['%' t]);
else
    num = NaN;
end

%%---------------------------------------------------------------------
function num = extract_col_num_octave(n, c, t)
if c <= length(n{1}.col)
    num = sscanf(n{1}.col{c}, ['%' t]);
else
    num = NaN;
end

%%---------------------------------------------------------------------
function num = extract_col_qnum(n, c, t)
if c <= length(n)
    str = n(c).col;
    if ~isempty(str) && (str(1) == '''' || str(1) == '"')
        str = str(2:end-1);
    end
    num = sscanf(str, ['%' t]);
else
    num = NaN;
end

%%---------------------------------------------------------------------
function num = extract_col_qnum_octave(n, c, t)
if c <= length(n{1}.col)
    str = n{1}.col{c};
    if ~isempty(str) && (str(1) == '''' || str(1) == '"')
        str = str(2:end-1);
    end
    num = sscanf(str, ['%' t]);
else
    num = NaN;
end
