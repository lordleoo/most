function full_idx = get_full_idx(om,QP,which_field)
% by Baraa Mohandes
% full_idx = get_full_idx(om,QP,which_field)
% Inputs:
% om: the opt_model. i.e: mdo.om                    This input is mandatory
% QP: the QP matrix in mdo. i.e. mdo.QP;            This input is optional
% which_field: if you don't want to produce the full list of indices
%              for 'var', 'lin' and 'qdc'
%              if you want to declare the third input which_field
%              but not the second input QP
%              then you should call: get_full_idx(om,[],which_field)
%              if "which_field" was NOT provided, all 3 fields 'var' 'lin' and 'qdc' will be analyzed
% 
% Outputs:
% full_idx is a structure of three fields: full_idx.var and full_idx.lin, full_idx.qdc
% each one of these fields is another structure (nested structure) containing two fields:
% full_list and full_order
% full_list contains an n x m cell array
% 
% a matpower object (OM or opt_model) aggregates the Pg variable for all machines in a system
% as one variable with om.var.idx.i1 reported as 1, and om.var.idx.iN as 1+ng
% if you want to extract the xmin, xmax and x0 for a certain machine, there is no built-in way
% to do that. You'd have to look at mdo.QP.xmin(om.var.idx.i1+ g)
% this manual approach has high potential for error. It gets nasty when you have multiple time periods
% multiple wind scenarios and multiple contingency scenarios.
% Therefore, get_full_idx generates a full list of indices, not only for 'var' but also for 'lin' and 'qdc'
% as stated above, 
% full_idx.var.full_list is an nvars x 4 cell array
% The first column is the number of this pack of variables (for {t,j,k}) combining (ng) variables
% This pack of variables is broken down to each one of its components (ng)
% The second column is the second index (n out of ng)
% The third column is the linear index of this variable (as if you were to use sub2ind(column1,column2)
% The fourth column is an extended name of this variable
% 
% full_idx.lin.full_list is an om.lin.N x 5 cell array 
% Columns 1, 2, 3 and 6 carry the same meaning (or report the same information) explained for full_idx.var.full_list
% The 5th column, however, contains a list of all variables involved in this constraint
% 
%  
% full_idx.qdc.full_list is an om.qdc.N x 5 cell array
% Columns 1, 2, 3 and 6 carry the same meaning (or report the same information) explained for full_idx.var.full_list
% The 5th column, however, contains a list of all variables involved in this cost
% 
% 
% get_full_idx is a bit slow because of the number of for-loops inside
% I'd call it only once for large models.
% 
% 
% Example: use the tutorial in MOST manual under "GETTING STARTED" page 13
% 
% mpc = loadcase('ex_case3b'); 
% transmat = ex_transmat(12); 
% xgd = loadxgendata('ex_xgd_uc', mpc); 
% [iwind, mpc, xgd] = addwind('ex_wind_uc', mpc, xgd); 
% [iess, mpc, xgd, sd] = addstorage('ex_storage', mpc, xgd); 
% contab = ex_contab();
% profiles = getprofiles('ex_load_profile'); 
% profiles = getprofiles('ex_wind_profile', profiles, iwind); 
% mdi = loadmd(mpc, transmat, xgd, sd, contab, profiles); 
% mpopt = mpoption('verbose', 3);  
% mdo = most(mdi, mpopt); mdo1 = mdo;
% 
% 
% %Now call get_full_idx
% full_idx = get_full_idx(mdo.om,mdo.QP);
% 
% 
% 
% 
% Old explanation:
% The advantage of this function is getting also the ID of a constraint (or variable), within the full set of constraints (or variables)
% that is, out of om.lin.N (or om.var.N)
% this helps identifying a certain constraint (or variable) to modify it inside om.QP.A, om.QP.u, om.QP.l
% 
% first column in full_idx.(lin) is number of this constraint subset, out of om.lin.NS
% second column in full_idx.(lin) is number of this one constraint within its subset, out of om.lin.idx.N.(this subset)
% third column in full_idx.(lin) is number of this one constraint in QP.A and QP.l and QP.u
% fourth column in full_idx.(lin) is its name
% 
% first column in full_idx.(lin) is number of this constraint subset, out of om.lin.NS
% second column in full_idx.(lin) is number of this one constraint within its subset, out of om.lin.idx.N.(this subset)
% third column in full_idx.(lin) is number of this one constraint in QP.A and QP.l and QP.u
% fourth column in full_idx.(lin) is its name
% 
% 
% edit @opt_model\get_full_idx
% 
% 

if ~exist('which_field') || isempty(which_field)
which_field = [1 1 1];
else
which_field = [any(contains(which_field,'var','ignorecase',true)),any(contains(which_field,'lin','ignorecase',true)),any(contains(which_field,'qdc','ignorecase',true))];
end

full_idx = struct('var',struct('full_list',{cell(om.var.NS,4)},'full_order',struct()),'lin',struct('full_list',{cell(om.lin.NS,5)},'full_order',struct()),'qdc',struct('full_list',{cell(om.qdc.NS,5)},'full_order',struct()));
if om.var.NS && which_field(1)
    idx = om.var.idx;
    for k = 1:om.var.NS
        name = om.var.order(k).name;
        if isempty(om.var.order(k).idx)
%             fprintf('%10d:%19s %8d %8d %8d\n', k, name, idx.i1.(name), idx.iN.(name), idx.N.(name)); disp('passed here'); beep;
        for iter_sub = 1:idx.N.(name); full_idx.var.full_list(idx.i1.(name)+iter_sub-1,:) = {k, iter_sub, idx.i1.(name)+iter_sub-1, [name,'(',num2str(iter_sub),')']};end;
        else
            vsidx = om.var.order(k).idx;
            str = strjoin(repmat({'%d'},1,length(vsidx)),',');
            s = substruct('.', name, '()', vsidx);
            for iter_sub = 1:subsref(idx.N, s)
            nname = sprintf(['%s(' str, ',%d)'], name, vsidx{:},iter_sub);
            full_idx.var.full_list(subsref(idx.i1,s)+iter_sub-1,:) = {k, iter_sub, subsref(idx.i1, s)+iter_sub-1,nname};
%             fprintf('(%5d,%3d) = %5d :%19s\n', full_idx.var{subsref(idx.i1,s)+iter_sub-1,:});
            end
        clear s;
        end
    end
assert(size(full_idx.var.full_list,1)==om.var.N,'Error in size(full_idx.var)');

vars_names = fieldnames(idx.i1);
full_idx.var.full_order = cell2struct(cell(numel(vars_names),1),vars_names,1);
for iter_var = 1:numel(vars_names)
full_idx.var.full_order.(vars_names{iter_var}) = find(contains(full_idx.var.full_list(:,end),vars_names{iter_var}));
end
end
clear idx;
%%
clear vsidx str s nname k name idx;
if om.lin.NS && which_field(2)
    idx = om.lin.idx;
    for k = 1:om.lin.NS
        name = om.lin.order(k).name;
        if isempty(om.lin.order(k).idx)
%             fprintf('%10d:%19s %8d %8d %8d\n', k, name, idx.i1.(name), idx.iN.(name), idx.N.(name));
        for iter_sub = 1:idx.N.(name)
            full_idx.lin.full_list(idx.i1.(name)+iter_sub-1,:) = {k, iter_sub, idx.i1.(name)+iter_sub-1,[], [name,'(',num2str(iter_sub),')']};
        end
        else
            vsidx = om.lin.order(k).idx;
            str = strjoin(repmat({'%d'},1,length(vsidx)),','); %str = strjoin(cellfun(@num2str,vsidx,'un',0),',');
            s = substruct('.', name, '()', vsidx);
            for iter_sub = 1:subsref(idx.N, s)
            nname = sprintf(['%s(' str, ',%d)'], name, vsidx{:},iter_sub);
            if ~exist('QP') || ~isempty(QP); vars_involved = find(QP.A(subsref(idx.i1, s)+iter_sub-1,:)); else; vars_involved = ['QP wasn''t provided']; end;
            full_idx.lin.full_list(subsref(idx.i1,s)+iter_sub-1,:) = {k, iter_sub, subsref(idx.i1, s)+iter_sub-1,[vars_involved], nname};
%             fprintf('(%5d,%3d) = %5d :%19s\n', full_idx.lin{subsref(idx.i1,s)+iter_sub-1,:});
            end
        clear s;
        end
    end

assert(size(full_idx.lin.full_list,1)==om.lin.N,'Error in size(full_idx.lin)');
lins_names = fieldnames(idx.i1);
full_idx.lin.full_order = cell2struct(cell(numel(lins_names),1),lins_names,1);
for iter_lin = 1:numel(lins_names)
full_idx.lin.full_order.(lins_names{iter_lin}) = find(contains(full_idx.lin.full_list(:,end),lins_names{iter_lin}));
end
end
clear idx;
%%
clear vsidx str s nname k name idx;
if om.qdc.NS && which_field(3)
    idx = om.qdc.idx;
    for k = 1:om.qdc.NS
        name = om.qdc.order(k).name;
        if isempty(om.qdc.order(k).idx)
%             fprintf('%10d:%19s %8d %8d %8d\n', k, name, idx.i1.(name), idx.iN.(name), idx.N.(name)); disp('passed here'); beep;
            for iter_sub = 1:idx.N.(name)
                full_idx.qdc.full_list(idx.i1.(name)+iter_sub-1,:) = {k, iter_sub, idx.i1.(name)+iter_sub-1,[], [name,'(',num2str(iter_sub),')']};
            end
        else
            vsidx = om.qdc.order(k).idx;
            str = strjoin(repmat({'%d'},1,length(vsidx)),',');
            s = substruct('.', name, '()', vsidx);
            my_s = substruct('.', name, '{}', vsidx);
            for iter_sub = 1:subsref(idx.N, s)
            nname = sprintf(['%s(' str, ',%d)'], name, vsidx{:},iter_sub);
            vars_involved = arrayfun(@(i) [subsref(om.qdc.data.vs,[my_s,substruct('()',{i},'.','name')]),'(',strjoin(cellfun(@num2str,subsref(om.qdc.data.vs,[my_s,substruct('()',{i},'.','idx')]),'un',0),','),')'],[1:numel(subsref(om.qdc.data.vs,my_s))]','un',0);
            full_idx.qdc.full_list(subsref(idx.i1,s)+iter_sub-1,:) = {k, iter_sub, subsref(idx.i1, s)+iter_sub-1, [vars_involved], nname};
%             fprintf('(%5d,%3d) = %5d :%19s\n', full_idx.lin{subsref(idx.i1,s)+iter_sub-1,:});
            end
        clear s;
        end
    end
assert(size(full_idx.qdc.full_list,1)==om.qdc.N,'Error in size(full_idx.qdc)');
qdcs_names = fieldnames(idx.i1);
full_idx.qdc.full_order = cell2struct(cell(numel(qdcs_names),1),qdcs_names,1);
for iter_qdc = 1:numel(qdcs_names)
full_idx.qdc.full_order.(qdcs_names{iter_qdc}) = find(contains(full_idx.qdc.full_list(:,end),qdcs_names{iter_qdc}));
end
end
clear idx;
end